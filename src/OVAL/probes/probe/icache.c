/*
 * Copyright 2011 Red Hat Inc., Durham, North Carolina.
 * All Rights Reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * Authors:
 *      Daniel Kopecek <dkopecek@redhat.com>
 */
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <pthread.h>
#include <stddef.h>
#include <sexp.h>
#include <errno.h>
#include <string.h>
#include <inttypes.h>

#include "common/public/alloc.h"
#include "common/assume.h"
#include "../SEAP/generic/rbt/rbt.h"
#include "probe-api.h"
#include "common/debug_priv.h"

#include "probe.h"
#include "icache.h"

static volatile uint32_t next_ID = 0;

#if !defined(HAVE_ATOMIC_FUNCTIONS)
pthread_mutex_t next_ID_mutex = PTHREAD_MUTEX_INITIALIZER;
#endif

static void probe_icache_item_setID(SEXP_t *item, SEXP_ID_t item_ID)
{
        SEXP_t  *name_ref, *prev_id;
        SEXP_t   uniq_id;
        uint32_t local_id;

        /* ((foo_item :id "<int>") ... ) */

        assume_d(item != NULL, /* void */);
        assume_d(SEXP_listp(item), /* void */);

#if defined(HAVE_ATOMIC_FUNCTIONS)
        local_id = __sync_fetch_and_add(&next_ID, 1);
#else
        if (pthread_mutex_lock(&next_ID_mutex) != 0) {
                dE("Can't lock the next_ID_mutex: %u, %s\n", errno, strerror(errno));
                abort();
        }

        local_id = ++next_ID;

        if (pthread_mutex_unlock(&next_ID_mutex) != 0) {
                dE("Can't unlock the next_ID_mutex: %u, %s\n", errno, strerror(errno));
                abort();
        }
#endif
        SEXP_string_newf_r(&uniq_id, "1%05u%u", getpid(), local_id);

        name_ref = SEXP_listref_first(item);
        prev_id  = SEXP_list_replace(name_ref, 3, &uniq_id);

        SEXP_free(prev_id);
        SEXP_free_r(&uniq_id);
        SEXP_free(name_ref);

        return;
}

static void *probe_icache_worker(void *arg)
{
        probe_icache_t *cache = (probe_icache_t *)(arg);
        probe_iqpair_t *pair;
        SEXP_ID_t       item_ID;

        assume_d(cache != NULL, NULL);

        if (pthread_mutex_lock(&cache->queue_mutex) != 0) {
                dE("An error ocured while locking the queue mutex: %u, %s\n",
                   errno, strerror(errno));
                return (NULL);
        }

        dI("icache worker ready\n");

        while(pthread_cond_wait(&cache->queue_notempty, &cache->queue_mutex) == 0) {
                assume_d(cache->queue_cnt > 0, NULL);
        next:
                dI("Extracting item from the cache queue: cnt=%"PRIu16", beg=%"PRIu16"\n", cache->queue_cnt, cache->queue_beg);
                /*
                 * Extract an item from the queue and update queue beg, end & cnt
                 */
                pair = cache->queue + cache->queue_beg;

                --cache->queue_cnt;

                if (cache->queue_end != cache->queue_beg) {
                        if (++cache->queue_beg == cache->queue_max)
                                cache->queue_beg = 0;
                }

                /*
                 * Release the mutex
                 */
                if (pthread_mutex_unlock(&cache->queue_mutex) != 0) {
                        dE("An error ocured while unlocking the queue mutex: %u, %s\n",
                           errno, strerror(errno));
                        abort();
                }

                dI("Signaling `notfull'\n");

                if (pthread_cond_signal(&cache->queue_notfull) != 0) {
                        dE("An error ocured while signaling the `notfull' condition: %u, %s\n",
                           errno, strerror(errno));
                        abort();
                }

                if (pair->cobj == NULL) {
                        /*
                         * Handle NOP case (synchronization)
                         */
                        assume_d(pair->p.cond != NULL, NULL);

                        dI("Handling NOP\n");

                        if (pthread_cond_signal(pair->p.cond) != 0) {
                                dE("An error ocured while signaling NOP condition: %u, %s\n",
                                   errno, strerror(errno));
                                abort();
                        }
                } else {
                        probe_citem_t *cached = NULL;

                        dI("Handling cache request\n");

                        /*
                         * Compute item ID
                         */
                        item_ID = SEXP_ID_v(pair->p.item);
                        dI("item ID=%"PRIu64"\n", item_ID);

                        /*
                         * Perform cache lookup
                         */
                        if (rbt_i64_get(cache->tree, (int64_t)item_ID, (void *)&cached) == 0) {
                                register uint16_t i;
                                /*
                                 * Maybe a cache HIT
                                 */
                                dI("cache HIT #1\n");

                                for (i = 0; i < cached->count; ++i) {
                                        if (SEXP_deepcmp(pair->p.item, cached->item[i]))
                                                break;
                                }

                                if (i == cached->count) {
                                        /*
                                         * Cache MISS
                                         */
                                        dI("cache MISS\n");

                                        cached->item = oscap_realloc(cached->item, sizeof(SEXP_t *) * ++cached->count);
                                        cached->item[cached->count - 1] = pair->p.item;

                                        /* Assign an unique item ID */
                                        probe_icache_item_setID(pair->p.item, item_ID);
                                } else {
                                        /*
                                         * Cache HIT
                                         */
                                        dI("cache HIT #2 -> real HIT\n");
                                        SEXP_free(pair->p.item);
                                        pair->p.item = cached->item[i];
                                }
                        } else {
                                /*
                                 * Cache MISS
                                 */
                                dI("cache MISS\n");
                                cached = oscap_talloc(probe_citem_t);
                                cached->item = oscap_talloc(SEXP_t *);
                                cached->item[0] = pair->p.item;
                                cached->count = 1;

                                /* Assign an unique item ID */
                                probe_icache_item_setID(pair->p.item, item_ID);

                                if (rbt_i64_add(cache->tree, (int64_t)item_ID, (void *)cached, NULL) != 0) {
                                        dE("Can't add item (k=%"PRIi64" to the cache (%p)\n", (int64_t)item_ID, cache->tree);

                                        oscap_free(cached->item);
                                        oscap_free(cached);

                                        /* now what? */
                                        abort();
                                }
                        }

                        if (probe_cobj_add_item(pair->cobj, pair->p.item) != 0) {
                                dE("An error ocured while adding an item to the collected object\n");
                                return (NULL);
                        }
                }

                if (pthread_mutex_lock(&cache->queue_mutex) != 0) {
                        dE("An error ocured while re-locking the queue mutex: %u, %s\n",
                           errno, strerror(errno));
                        return (NULL);
                }

                if (cache->queue_cnt > 0)
                        goto next;
        }

        return (NULL);
}

probe_icache_t *probe_icache_new(void)
{
        probe_icache_t *cache;

        cache = oscap_talloc(probe_icache_t);
        cache->tree = rbt_i64_new();

        if (pthread_mutex_init(&cache->queue_mutex, NULL) != 0) {
                dE("Can't initialize icache mutex: %u, %s\n", errno, strerror(errno));
                goto fail;
        }

        cache->queue_beg = 0;
        cache->queue_end = 0;
        cache->queue_cnt = 0;
        cache->queue_max = PROBE_IQUEUE_CAPACITY;

        if (pthread_cond_init(&cache->queue_notempty, NULL) != 0) {
                dE("Can't initialize icache queue condition variable (notempty): %u, %s\n",
                   errno, strerror(errno));
                goto fail;
        }

        if (pthread_cond_init(&cache->queue_notfull, NULL) != 0) {
                dE("Can't initialize icache queue condition variable (notfull): %u, %s\n",
                   errno, strerror(errno));
                goto fail;
        }

        if (pthread_create(&cache->thid, NULL,
                           probe_icache_worker, (void *)cache) != 0)
        {
                dE("Can't start the icache worker: %u, %s\n", errno, strerror(errno));
                goto fail;
        }

        return (cache);
fail:
        if (cache->tree != NULL)
                rbt_i64_free(cache->tree);

        pthread_mutex_destroy(&cache->queue_mutex);
        pthread_cond_destroy(&cache->queue_notempty);
        oscap_free(cache);

        return (NULL);
}

static int __probe_icache_add_nolock(probe_icache_t *cache, SEXP_t *cobj, SEXP_t *item, pthread_cond_t *cond)
{
        assume_d((cond == NULL) ^ (item == NULL), -1);
retry:
        if (cache->queue_cnt <= cache->queue_max) {
                cache->queue[cache->queue_end].cobj = cobj;

                if (item != NULL)
                        cache->queue[cache->queue_end].p.item = item;
                else
                        cache->queue[cache->queue_end].p.cond = cond;

                ++cache->queue_cnt;

                if (cache->queue_end + 1 == cache->queue_max)
                        cache->queue_end = 0;
                else
                        ++cache->queue_end;
        } else {
                /*
                 * The queue is full, we have to wait
                 */
                if (pthread_cond_wait(&cache->queue_notfull, &cache->queue_mutex) == 0)
                        goto retry;
                else {
                        dE("An error ocured while waiting for the `notfull' queue condition: %u, %s\n",
                           errno, strerror(errno));
                        return (-1);
                }
        }

        return (0);
}

int probe_icache_add(probe_icache_t *cache, SEXP_t *cobj, SEXP_t *item)
{
        int ret;

        if (cache == NULL || cobj == NULL || item == NULL)
                return (-1); /* XXX: EFAULT */

        if (pthread_mutex_lock(&cache->queue_mutex) != 0) {
                dE("An error ocured while locking the queue mutex: %u, %s\n",
                   errno, strerror(errno));
                return (-1);
        }

        ret = __probe_icache_add_nolock(cache, cobj, item, NULL);

        if (pthread_mutex_unlock(&cache->queue_mutex) != 0) {
                dE("An error ocured while unlocking the queue mutex: %u, %s\n",
                   errno, strerror(errno));
                abort();
        }

        if (ret != 0)
                return (-1);

        if (pthread_cond_signal(&cache->queue_notempty) != 0) {
                dE("An error ocured while signaling the `notempty' condition: %u, %s\n",
                   errno, strerror(errno));
                return (-1);
        }

        return (0);
}

int probe_icache_nop(probe_icache_t *cache)
{
        pthread_cond_t cond;

        dI("NOP\n");

        if (pthread_mutex_lock(&cache->queue_mutex) != 0) {
                dE("An error ocured while locking the queue mutex: %u, %s\n",
                   errno, strerror(errno));
                return (-1);
        }

        if (pthread_cond_init(&cond, NULL) != 0) {
                dE("Can't initialize icache queue condition variable (NOP): %u, %s\n",
                   errno, strerror(errno));
                return (-1);
        }

        if (__probe_icache_add_nolock(cache, NULL, NULL, &cond) != 0) {
                if (pthread_mutex_unlock(&cache->queue_mutex) != 0) {
                        dE("An error ocured while unlocking the queue mutex: %u, %s\n",
                           errno, strerror(errno));
                        abort();
                }

                pthread_cond_destroy(&cond);
                return (-1);
        }

        dI("Signaling `notempty'\n");

        if (pthread_cond_signal(&cache->queue_notempty) != 0) {
                dE("An error ocured while signaling the `notempty' condition: %u, %s\n",
                   errno, strerror(errno));

                pthread_cond_destroy(&cond);
                return (-1);
        }

        dI("Waiting for icache worker to handle the NOP\n");

        if (pthread_cond_wait(&cond, &cache->queue_mutex) != 0) {
                dE("An error ocured while waiting for the `NOP' queue condition: %u, %s\n",
                   errno, strerror(errno));
                return (-1);
        }

        dI("Sync\n");

        if (pthread_mutex_unlock(&cache->queue_mutex) != 0) {
                dE("An error ocured while unlocking the queue mutex: %u, %s\n",
                   errno, strerror(errno));
                abort();
        }

        pthread_cond_destroy(&cond);

        return (0);
}

int probe_item_collect(struct probe_ctx *ctx, SEXP_t *item)
{
        if (ctx->filters != NULL && probe_item_filtered(item, ctx->filters)) {
                SEXP_free(item);
		return (1);
        }

        if (probe_icache_add(ctx->icache, ctx->probe_out, item) != 0) {
                dE("Can't add item (%p) to the item cache (%p)\n", item, ctx->icache);
                SEXP_free(item);
                return (-1);
        }

        return (0);
}

static void probe_icache_free_node(struct rbt_i64_node *n)
{
        probe_citem_t *ci = (struct probe_citem_t *)n->data;

        while (ci->count > 0) {
                SEXP_free(ci->item[ci->count - 1]);
                --ci->count;
        }

        oscap_free(ci->item);
        return;
}

void probe_icache_free(probe_icache_t *cache)
{
        void *ret = NULL;

        pthread_cancel(cache->thid);
        pthread_join(cache->thid, &ret);
        pthread_mutex_destroy(&cache->queue_mutex);
        pthread_cond_destroy(&cache->queue_notempty);
        pthread_cond_destroy(&cache->queue_notfull);

        rbt_i64_free_cb(cache->tree, &probe_icache_free_node);
        oscap_free(cache);
        return;
}
