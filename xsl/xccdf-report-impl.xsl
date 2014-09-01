<?xml version="1.0" encoding="utf-8" ?>

<!--
Copyright 2010-2014 Red Hat Inc., Durham, North Carolina.
All Rights Reserved.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA

Authors:
     Martin Preisler <mpreisle@redhat.com>
     Lukas Kuklinek <lkuklinek@redhat.com>
-->

<xsl:stylesheet version="1.1"
	xmlns="http://www.w3.org/1999/xhtml"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:cdf="http://checklists.nist.gov/xccdf/1.2"
    xmlns:ovalres="http://oval.mitre.org/XMLSchema/oval-results-5"
    xmlns:sceres="http://open-scap.org/page/SCE_result_file"
    xmlns:exsl="http://exslt.org/common"
    exclude-result-prefixes="xsl cdf ovalres sceres exsl">

<xsl:include href="xccdf-branding.xsl" />
<xsl:include href="xccdf-resources.xsl" />
<xsl:include href="xccdf-share.xsl" />

<xsl:include href="xccdf-report-oval-details.xsl" />

<xsl:output
    method="html"
    encoding="utf-8"
    indent="no"
    omit-xml-declaration="yes"/>

<xsl:template name="characteristics">
    <xsl:param name="testresult"/>
    <xsl:param name="benchmark"/>

    <div id="characteristics"><a name="characteristics"></a>
        <h2>Evaluation Characteristics</h2>
        <div class="row">
            <div class="col-md-5 well well-lg">
                <table class="table table-bordered">
                    <tr>
                        <th>Target machine</th>
                        <td>
                            <xsl:value-of select="$testresult/cdf:target/text()"/>
                        </td>
                    </tr>
                    <xsl:if test="$testresult/cdf:benchmark">
                        <tr>
                            <th>Benchmark URL</th>
                            <td><xsl:value-of select="$testresult/cdf:benchmark/@href"/></td>
                        </tr>
                        <xsl:if test="$testresult/cdf:benchmark/@id">
                            <tr>
                                <th>Benchmark ID</th>
                                <td><xsl:value-of select="$testresult/cdf:benchmark/@id"/></td>
                            </tr>
                        </xsl:if>
                    </xsl:if>
                    <xsl:if test="$testresult/cdf:profile">
                        <tr>
                            <th>Profile ID</th>
                            <td><xsl:value-of select="$testresult/cdf:profile/@idref"/></td>
                        </tr>
                    </xsl:if>
                    <tr>
                        <th>Started at</th>
                        <td>
                            <xsl:choose>
                                <xsl:when test="$testresult/@start-time">
                                    <xsl:value-of select="$testresult/@start-time"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    unknown time
                                </xsl:otherwise>
                            </xsl:choose>
                        </td>
                    </tr>
                    <tr>
                        <th>Finished at</th>
                        <td>
                            <xsl:value-of select="$testresult/@end-time"/>
                        </td>
                    </tr>
                    <tr>
                        <th>Performed by</th>
                        <td>
                            <xsl:choose>
                                <xsl:when test="$testresult/cdf:identity">
                                    <xsl:value-of select="$testresult/cdf:identity/text()"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    unknown user
                                </xsl:otherwise>
                            </xsl:choose>
                        </td>
                    </tr>
                </table>
            </div>
            <div class="col-md-3">
                <h4>CPE Platforms</h4>
                <ul class="list-group">
                    <!-- all the applicable platforms first -->
                    <xsl:for-each select="$benchmark/cdf:platform">
                        <xsl:variable name="idref" select="@idref"/>
                        <xsl:if test="$testresult/cdf:platform[@idref=$idref]">
                            <li class="list-group-item">
                                <span class="label label-success" title="CPE platform {@idref} was found applicable on the evaluated machine"><xsl:value-of select="@idref"/></span>
                            </li>
                        </xsl:if>
                    </xsl:for-each>
                    <!-- then the rest -->
                    <xsl:for-each select="$benchmark/cdf:platform">
                        <xsl:variable name="idref" select="@idref"/>
                        <xsl:if test="not($testresult/cdf:platform[@idref=$idref])">
                            <li class="list-group-item">
                                <span class="label label-default" title="This CPE platform was not applicable on the evaluated machine"><xsl:value-of select="@idref"/></span>
                            </li>
                        </xsl:if>
                    </xsl:for-each>
                </ul>
            </div>
            <div class="col-md-4">
                <h4>Addresses</h4>
                <ul class="list-group">
                    <!-- the second predicate ensures that we don't print duplicates -->
                    <xsl:for-each select="$testresult/cdf:target-address[not(. = preceding::cdf:target-address)]">
                        <li class="list-group-item">
                            <xsl:choose>
                                <xsl:when test="contains(text(), ':')">
                                    <span class="label label-info">IPv6</span>
                                </xsl:when>
                                <xsl:when test="contains(text(), '.')">
                                    <span class="label label-primary">IPv4</span>
                                </xsl:when>
                                <xsl:otherwise>
                                </xsl:otherwise>
                            </xsl:choose>
                            <!-- #160 is nbsp -->
                            &#160;<xsl:value-of select="text()"/>
                        </li>
                    </xsl:for-each>
                    <!-- the second predicate ensures that we don't print duplicates -->
                    <xsl:for-each select="$testresult/cdf:target-facts/cdf:fact[@name = 'urn:xccdf:fact:ethernet:MAC'][not(. = preceding::cdf:fact)]">
                        <li class="list-group-item">
                            <span class="label label-default">MAC</span>
                            <!-- #160 is nbsp -->
                            &#160;<xsl:value-of select="text()"/>
                        </li>
                    </xsl:for-each>
                </ul>
            </div>
        </div>
    </div>
</xsl:template>

<xsl:template name="compliance-and-scoring">
    <xsl:param name="testresult"/>

    <div id="compliance-and-scoring"><a name="compliance-and-scoring"></a>
        <h2>Compliance and Scoring</h2>
        <xsl:choose>
            <xsl:when test="$testresult/cdf:rule-result/cdf:result[text() = 'fail' or text() = 'error']">
                <div class="alert alert-danger">
                    <strong>The system is not compliant!</strong> Please review rule results and consider applying remediation.
                </div>
            </xsl:when>
            <xsl:when test="$testresult/cdf:rule-result/cdf:result[text() = 'unknown']">
                <div class="alert alert-warning">
                    <strong>The system could be not compliant!</strong> Results from one or more rules could not be interpreted.
                </div>
            </xsl:when>
            <xsl:otherwise>
                <div class="alert alert-success">
                    <strong>The system is fully compliant!</strong> No action is necessary.
                </div>
            </xsl:otherwise>
        </xsl:choose>

        <xsl:variable name="total_rules_count" select="count($testresult/cdf:rule-result[cdf:result])"/>
        <xsl:variable name="ignored_rules_count" select="count($testresult/cdf:rule-result[cdf:result/text() = 'notselected' or cdf:result/text() = 'notapplicable'])"/>
        <xsl:variable name="passed_rules_count" select="count($testresult/cdf:rule-result[cdf:result/text() = 'pass' or cdf:result/text() = 'fixed'])"/>
        <xsl:variable name="failed_rules_count" select="count($testresult/cdf:rule-result[cdf:result/text() = 'fail' or cdf:result/text() = 'error'])"/>

        <h3>Rule result breakdown</h3>
        <div class="progress" title="Displays proportion of passed/fixed, failed/error, and other rules (in that order). There were {$total_rules_count - $ignored_rules_count} rules taken into account.">
            <div class="progress-bar progress-bar-success" style="width: {$passed_rules_count div ($total_rules_count - $ignored_rules_count) * 100}%">
                <xsl:value-of select="$passed_rules_count"/> passed
            </div>
            <div class="progress-bar progress-bar-danger" style="width: {$failed_rules_count div ($total_rules_count - $ignored_rules_count) * 100}%">
                <xsl:value-of select="$failed_rules_count"/> failed
            </div>
            <div class="progress-bar progress-bar-warning" style="width: {(1 - ($passed_rules_count + $failed_rules_count) div ($total_rules_count - $ignored_rules_count)) * 100}%">
                <xsl:value-of select="$total_rules_count - $ignored_rules_count - $passed_rules_count - $failed_rules_count"/> other
            </div>
        </div>

        <xsl:variable name="failed_rules_high_severity" select="count($testresult/cdf:rule-result[(cdf:result/text() = 'fail') and (@severity = 'high')])"/>
        <xsl:variable name="failed_rules_medium_severity" select="count($testresult/cdf:rule-result[(cdf:result/text() = 'fail') and (@severity = 'medium')])"/>
        <xsl:variable name="failed_rules_low_severity" select="count($testresult/cdf:rule-result[(cdf:result/text() = 'fail') and (@severity = 'low')])"/>
        <xsl:variable name="failed_rules_other_severity" select="$failed_rules_count - $failed_rules_high_severity - $failed_rules_medium_severity - $failed_rules_low_severity"/>

        <h3>Failed rules by severity breakdown</h3>
        <div class="progress" title="Displays proportion of high, medium, low, and other severity failed rules (in that order). There were {$failed_rules_count} total failed rules.">
            <div class="progress-bar progress-bar-danger" style="width: {$failed_rules_high_severity div $failed_rules_count * 100}%">
                <xsl:value-of select="$failed_rules_high_severity"/> high
            </div>
            <div class="progress-bar progress-bar-warning" style="width: {$failed_rules_medium_severity div $failed_rules_count * 100}%">
                <xsl:value-of select="$failed_rules_medium_severity"/> medium
            </div>
            <div class="progress-bar progress-bar-info" style="width: {$failed_rules_low_severity div $failed_rules_count * 100}%">
                <xsl:value-of select="$failed_rules_low_severity"/> low
            </div>
            <div class="progress-bar progress-bar-success" style="width: {$failed_rules_other_severity div $failed_rules_count * 100}%">
                <xsl:value-of select="$failed_rules_other_severity"/> other
            </div>
        </div>

        <h3>Score</h3>
        <table class="table table-striped table-bordered">
            <thead>
                <tr>
                    <th>Scoring system</th>
                    <th class="text-center">Score</th>
                    <th class="text-center">Maximum</th>
                    <th class="text-center" style="width: 40%">%</th>
                </tr>
            </thead>
            <tbody>
                <xsl:for-each select="$testresult/cdf:score">
                    <xsl:variable name="percent" select="(text() div @maximum) * 100"/>
                    <tr>
                        <td><xsl:value-of select="@system"/></td>
                        <td class="text-center"><xsl:value-of select="text()"/></td>
                        <td class="text-center"><xsl:value-of select="@maximum"/></td>
                        <td>
                            <div class="progress">
                                <div class="progress-bar progress-bar-success" style="width: {$percent}%"><xsl:value-of select="round($percent * 100) div 100"/>%</div>
                                <div class="progress-bar progress-bar-danger" style="width: {100 - $percent}%"></div>
                            </div>
                        </td>
                    </tr>
                </xsl:for-each>
            </tbody>
        </table>
    </div>
</xsl:template>

<xsl:template name="rule-overview-leaf">
    <xsl:param name="testresult"/>
    <xsl:param name="item"/>
    <xsl:param name="profile"/>
    <xsl:param name="indent"/>

    <xsl:variable name="ruleresult" select="$testresult/cdf:rule-result[@idref = $item/@id]"/>
    <xsl:variable name="result" select="$ruleresult/cdf:result/text()"/>

    <tr data-tt-id="{$item/@id}" class="rule-overview-leaf rule-overview-leaf-{$result}" id="rule-overview-leaf-{generate-id($ruleresult)}">
        <xsl:attribute name="data-tt-parent-id">
            <xsl:value-of select="$item/parent::cdf:*/@id"/>
        </xsl:attribute>
        <xsl:if test="$result = 'fail' or $result = 'error' or $result = 'unknown'">
            <xsl:attribute name="class">rule-overview-leaf rule-overview-leaf-<xsl:value-of select="$result"/> rule-overview-needs-attention</xsl:attribute>
        </xsl:if>

        <td style="padding-left: {$indent * 19}px"><a href="#rule-detail-{generate-id($ruleresult)}" onclick="return openRuleDetailsDialog('{generate-id($ruleresult)}')">
            <xsl:call-template name="item-title">
                <xsl:with-param name="item" select="$item"/>
                <xsl:with-param name="testresult" select="$testresult"/>
                <xsl:with-param name="profile" select="$profile"/>
            </xsl:call-template>
        </a></td>
        <td style="text-align: center"><xsl:value-of select="$ruleresult/@severity"/></td>
        <td class="rule-result rule-result-{$result}">
            <xsl:variable name="result_tooltip">
                <xsl:call-template name="rule-result-tooltip">
                    <xsl:with-param name="ruleresult" select="$result"/>
                </xsl:call-template>
            </xsl:variable>
            <div>
                <abbr title="{$result_tooltip}"><xsl:value-of select="$result"/></abbr>
            </div>
        </td>
    </tr>
</xsl:template>

<xsl:template name="rule-overview-inner-node">
    <xsl:param name="testresult"/>
    <xsl:param name="item"/>
    <xsl:param name="profile"/>
    <xsl:param name="indent"/>

    <xsl:variable name="contained_rules_fail" select="count($item/descendant::cdf:Rule[@id = $testresult/cdf:rule-result[cdf:result/text() = 'fail']/@idref])"/>
    <xsl:variable name="contained_rules_error" select="count($item/descendant::cdf:Rule[@id = $testresult/cdf:rule-result[cdf:result/text() = 'error']/@idref])"/>
    <xsl:variable name="contained_rules_unknown" select="count($item/descendant::cdf:Rule[@id = $testresult/cdf:rule-result[cdf:result/text() = 'unknown']/@idref])"/>
    <xsl:variable name="contained_rules_need_attention" select="$contained_rules_fail + $contained_rules_error + $contained_rules_unknown"/>

    <tr data-tt-id="{$item/@id}">
        <xsl:if test="$item/parent::cdf:Group or $item/parent::cdf:Benchmark">
            <xsl:attribute name="data-tt-parent-id">
                <xsl:value-of select="$item/parent::cdf:*/@id"/>
            </xsl:attribute>
        </xsl:if>

        <td colspan="3" style="padding-left: {$indent * 19}px">
            <xsl:choose>
                <xsl:when test="$contained_rules_need_attention > 0">
                    <strong>
                        <xsl:call-template name="item-title">
                            <xsl:with-param name="item" select="$item"/>
                            <xsl:with-param name="testresult" select="$testresult"/>
                            <xsl:with-param name="profile" select="$profile"/>
                        </xsl:call-template>
                    </strong>
                    <xsl:if test="$contained_rules_fail > 0">&#160;<span class="badge"><xsl:value-of select="$contained_rules_fail"/>x fail</span></xsl:if>
                    <xsl:if test="$contained_rules_error > 0">&#160;<span class="badge"><xsl:value-of select="$contained_rules_error"/>x error</span></xsl:if>
                    <xsl:if test="$contained_rules_unknown > 0">&#160;<span class="badge"><xsl:value-of select="$contained_rules_unknown"/>x unknown</span></xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="item-title">
                        <xsl:with-param name="item" select="$item"/>
                        <xsl:with-param name="testresult" select="$testresult"/>
                        <xsl:with-param name="profile" select="$profile"/>
                    </xsl:call-template>
                    <script>$(document).ready(function(){$('.treetable').treetable("collapseNode","<xsl:value-of select="$item/@id"/>");});</script>
                </xsl:otherwise>
            </xsl:choose>
        </td>
    </tr>

    <xsl:for-each select="$item/cdf:Group">
        <xsl:call-template name="rule-overview-inner-node">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="item" select="."/>
            <xsl:with-param name="profile" select="$profile"/>
            <xsl:with-param name="indent" select="$indent + 1"/>
        </xsl:call-template>
    </xsl:for-each>

    <xsl:for-each select="$item/cdf:Rule">
        <xsl:call-template name="rule-overview-leaf">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="item" select="."/>
            <xsl:with-param name="profile" select="$profile"/>
            <xsl:with-param name="indent" select="$indent + 1"/>
        </xsl:call-template>
    </xsl:for-each>
</xsl:template>

<xsl:template name="rule-overview">
    <xsl:param name="testresult"/>
    <xsl:param name="benchmark"/>
    <xsl:param name="profile"/>

    <div id="rule-overview"><a name="rule-overview"></a>
        <h2>Rule Overview</h2>

        <div class="form-group js-only">
            <div class="row">
                <div title="Filter rules by their XCCDF result">
                    <div class="col-sm-2 toggle-rule-display-success">
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="pass"/>pass</label>
                        </div>
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="fixed"/>fixed</label>
                        </div>
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="informational"/>informational</label>
                        </div>
                    </div>

                    <div class="col-sm-2 toggle-rule-display-danger">
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="fail"/>fail</label>
                        </div>
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="error"/>error</label>
                        </div>
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="unknown"/>unknown</label>
                        </div>
                    </div>

                    <div class="col-sm-2 toggle-rule-display-other">
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="notchecked"/>notchecked</label>
                        </div>
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" value="notselected"/>notselected</label>
                        </div>
                        <div class="checkbox">
                            <label><input class="toggle-rule-display" type="checkbox" onclick="toggleRuleDisplay(this)" checked="checked" value="notapplicable"/>notapplicable</label>
                        </div>
                    </div>
                </div>
                <div class="col-sm-6">
                    <div class="input-group">
                        <input type="text" class="form-control" placeholder="Search through XCCDF rules" id="search-input" oninput="ruleSearch()"/>

                        <div class="input-group-btn">
                            <button class="btn btn-default" onclick="ruleSearch()">Search</button>
                        </div>
                    </div>
                    <p id="search-matches"></p>
                </div>
            </div>
        </div>

        <table class="treetable table table-striped table-bordered">
            <thead>
                <tr>
                    <th>Title</th>
                    <th style="width: 120px; text-align: center">Severity</th>
                    <th style="width: 120px; text-align: center">Result</th>
                </tr>
            </thead>
            <tbody>
                <xsl:call-template name="rule-overview-inner-node">
                    <xsl:with-param name="testresult" select="$testresult"/>
                    <xsl:with-param name="item" select="$benchmark"/>
                    <xsl:with-param name="profile" select="$profile"/>
                    <xsl:with-param name="indent" select="0"/>
                </xsl:call-template>
            </tbody>
        </table>
    </div>
</xsl:template>

<xsl:template name="check-system-details-oval5">
    <xsl:param name="check"/>
    <xsl:param name="oval-tmpl"/>

    <!-- TODO: Look into ARF OVAL results as well -->

    <xsl:variable name="filename">
        <xsl:choose>
            <xsl:when test='contains($oval-tmpl, "%")'><xsl:value-of select='concat(substring-before($oval-tmpl, "%"), $check/cdf:check-content-ref/@href, substring-after($oval-tmpl, "%"))'/></xsl:when>
            <xsl:otherwise><xsl:value-of select='$oval-tmpl'/></xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:if test="$filename != ''">
        <xsl:variable name="details">
            <xsl:apply-templates select="document($filename)/ovalres:oval_results" mode="brief">
                <xsl:with-param name='definition-id' select='$check/cdf:check-content-ref/@name'/>
            </xsl:apply-templates>
        </xsl:variable>

        <xsl:if test="normalize-space($details)">
            <span class="label label-default"><abbr title="OVAL details taken from '{$filename}'">OVAL details</abbr></span>
            <div class="panel panel-default">
                <div class="panel-body">
                    <xsl:copy-of select="$details"/>
                </div>
            </div>
        </xsl:if>
    </xsl:if>
</xsl:template>

<xsl:template name="check-system-details-sce">
    <xsl:param name="check"/>
    <xsl:param name="sce-tmpl"/>

    <xsl:choose>
        <xsl:when test="$check/cdf:check-import[@import-name = 'stdout']/text()">
            <span class="label label-default"><abbr title="Script Check Engine stdout taken from check-import">SCE stdout</abbr></span>
            <pre><code>
                <xsl:value-of select="$check/cdf:check-import[@import-name = 'stdout']/text()"/>
            </code></pre>
        </xsl:when>
        <xsl:otherwise>
            <xsl:variable name="filename">
                <xsl:choose>
                    <xsl:when test='contains($sce-tmpl, "%")'><xsl:value-of select='concat(substring-before($sce-tmpl, "%"), $check/@href, substring-after($sce-tmpl, "%"))'/></xsl:when>
                    <xsl:otherwise><xsl:value-of select='$sce-tmpl'/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <xsl:if test="$filename != ''">
                <xsl:variable name="stdout" select="document($filename)/sceres:sce_results/sceres:stdout/text()"/>

                <xsl:if test="normalize-space($stdout)">
                    <span class="label label-default"><abbr title="Script Check Engine stdout taken from '{$filename}'">SCE stdout</abbr></span>
                    <pre><code>
                        <xsl:copy-of select="$stdout"/>
                    </code></pre>
                </xsl:if>
            </xsl:if>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="check-system-details">
    <xsl:param name="check"/>
    <xsl:param name="oval-tmpl"/>
    <xsl:param name="sce-tmpl"/>

    <xsl:choose>
        <xsl:when test="$check/@system = 'http://oval.mitre.org/XMLSchema/oval-definitions-5'">
            <xsl:call-template name="check-system-details-oval5">
                <xsl:with-param name="check" select="$check"/>
                <xsl:with-param name="oval-tmpl" select="$oval-tmpl"/>
            </xsl:call-template>
        </xsl:when>
        <xsl:when test="$check/@system = 'http://open-scap.org/page/SCE'">
            <xsl:call-template name="check-system-details-sce">
                <xsl:with-param name="check" select="$check"/>
                <xsl:with-param name="sce-tmpl" select="$sce-tmpl"/>
            </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
        </xsl:otherwise>
    </xsl:choose>

</xsl:template>

<xsl:template name="result-details-leaf">
    <xsl:param name="testresult"/>
    <xsl:param name="item"/>
    <xsl:param name="profile"/>

    <xsl:variable name="ruleresult" select="$testresult/cdf:rule-result[@idref = $item/@id]"/>
    <xsl:variable name="result" select="$ruleresult/cdf:result/text()"/>

    <div class="panel panel-default rule-detail rule-detail-{$result}" id="rule-detail-{generate-id($ruleresult)}">
        <div class="keywords sr-only">
            <xsl:call-template name="item-title">
                <xsl:with-param name="item" select="$item"/>
                <xsl:with-param name="testresult" select="$testresult"/>
                <xsl:with-param name="profile" select="$profile"/>
            </xsl:call-template>
            <xsl:value-of select="concat($item/@id, ' ')"/>
            <xsl:for-each select="$ruleresult/cdf:ident">
                <xsl:value-of select="concat(text(), ' ')"/>
            </xsl:for-each>
            <xsl:for-each select="$ruleresult/cdf:reference">
                <xsl:value-of select="concat(text(), ' ')"/>
            </xsl:for-each>
        </div>
        <div class="panel-heading">
            <a name="rule-detail-{generate-id($ruleresult)}"></a>
            <h3 class="panel-title">
                <xsl:call-template name="item-title">
                    <xsl:with-param name="item" select="$item"/>
                    <xsl:with-param name="testresult" select="$testresult"/>
                    <xsl:with-param name="profile" select="$profile"/>
                </xsl:call-template>
            </h3>
        </div>
        <div class="panel-body">
            <table class="table table-striped table-bordered">
                <tbody>
                    <tr><td class="col-md-3">Rule ID</td><td class="rule-id col-md-9"><xsl:value-of select="$item/@id"/></td></tr>
                    <tr><td>Result</td>
                    <td class="rule-result rule-result-{$result}">
                        <xsl:variable name="result_tooltip">
                            <xsl:call-template name="rule-result-tooltip">
                                <xsl:with-param name="ruleresult" select="$result"/>
                            </xsl:call-template>
                        </xsl:variable>
                        <div>
                            <abbr title="{$result_tooltip}"><xsl:value-of select="$result"/></abbr>
                        </div>
                    </td></tr>
                    <tr><td>Time</td><td><xsl:value-of select="$ruleresult/@time"/></td></tr>
                    <tr><td>Severity</td><td><xsl:value-of select="$ruleresult/@severity"/></td></tr>
                    <tr><td>Identifiers and References</td><td class="identifiers">
                        <!-- XCCDF 1.2 spec says that idents in rule-result should be copied from
                             the Rule itself. That means that we can just use the same code as guide
                             and just use idents from Rule. -->
                        <xsl:call-template name="item-idents-refs">
                            <xsl:with-param name="item" select="$item"/>
                        </xsl:call-template>
                    </td></tr>
                    <tr><td colspan="2" class="description">
                        <p>
                            <xsl:apply-templates mode="sub-testresult" select="$item/cdf:description">
                                <xsl:with-param name="testresult" select="$testresult"/>
                                <xsl:with-param name="benchmark" select="$item/ancestor::cdf:Benchmark"/>
                                <xsl:with-param name="profile" select="$profile"/>
                            </xsl:apply-templates>
                        </p>
                    </td></tr>
                    <xsl:if test="$result = 'fail' or $result = 'error' or $result = 'unknown'">
                        <xsl:variable name="check_system_details_ret">
                            <xsl:call-template name="check-system-details">
                                <xsl:with-param name="check" select="$ruleresult/cdf:check"/>
                                <xsl:with-param name="oval-tmpl" select="$oval-tmpl"/>
                                <xsl:with-param name="sce-tmpl" select="$sce-tmpl"/>
                            </xsl:call-template>
                        </xsl:variable>

                        <xsl:if test="normalize-space($check_system_details_ret)">
                            <tr><td colspan="2"><div class="check-system-details">
                                <xsl:copy-of select="$check_system_details_ret"/>
                            </div></td></tr>
                        </xsl:if>
                        <xsl:if test="$item/cdf:fix">
                            <tr><td colspan="2"><div class="remediation">
                                <span class="label label-success">Remediation script:</span>
                                <pre><code>
                                    <xsl:apply-templates mode="sub-testresult" select="$item/cdf:fix">
                                        <xsl:with-param name="testresult" select="$testresult"/>
                                        <xsl:with-param name="benchmark" select="$item/ancestor::cdf:Benchmark"/>
                                        <xsl:with-param name="profile" select="$profile"/>
                                    </xsl:apply-templates>
                                </code></pre>
                            </div></td></tr>
                        </xsl:if>
                    </xsl:if>
                </tbody>
            </table>
        </div>
    </div>
</xsl:template>

<xsl:template name="result-details-inner-node">
    <xsl:param name="testresult"/>
    <xsl:param name="item"/>
    <xsl:param name="profile"/>

    <xsl:for-each select="$item/cdf:Group">
        <xsl:call-template name="result-details-inner-node">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="item" select="."/>
            <xsl:with-param name="profile" select="$profile"/>
        </xsl:call-template>
    </xsl:for-each>

    <xsl:for-each select="$item/cdf:Rule">
        <xsl:call-template name="result-details-leaf">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="item" select="."/>
            <xsl:with-param name="profile" select="$profile"/>
        </xsl:call-template>
    </xsl:for-each>
</xsl:template>

<xsl:template name="result-details">
    <xsl:param name="testresult"/>
    <xsl:param name="benchmark"/>
    <xsl:param name="profile"/>

    <div class="js-only">
        <button type="button" class="btn btn-info" onclick="return toggleResultDetails(this)">Show all result details</button>
    </div>
    <div id="result-details"><a name="result-details"></a>
        <h2>Result Details</h2>

        <xsl:call-template name="result-details-inner-node">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="item" select="$benchmark"/>
            <xsl:with-param name="profile" select="$profile"/>
        </xsl:call-template>
    </div>
</xsl:template>

<xsl:template name="generate-report">
    <xsl:param name="testresult"/>
    <xsl:param name="benchmark"/>

    <xsl:variable name="profile" select="$benchmark/cdf:Profile[@id = $testresult/cdf:profile/@idref]"/>

    <xsl:text disable-output-escaping='yes'>&lt;!DOCTYPE html></xsl:text>
    <html lang="en">
    <head>
        <meta charset="utf-8"/>
        <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title><xsl:value-of select="$testresult/@id"/> | OpenSCAP Evaluation Report</title>

        <style><xsl:call-template name="css-sources"/></style>
        <script><xsl:call-template name="js-sources"/></script>
    </head>

    <body>
    <xsl:call-template name="xccdf-report-header"/>

    <div class="container"><div id="content">
        <xsl:call-template name="characteristics">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="benchmark" select="$benchmark"/>
            <xsl:with-param name="profile" select="$profile"/>
        </xsl:call-template>
        <xsl:call-template name="compliance-and-scoring">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="benchmark" select="$benchmark"/>
            <xsl:with-param name="profile" select="$profile"/>
        </xsl:call-template>
        <xsl:call-template name="rule-overview">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="benchmark" select="$benchmark"/>
            <xsl:with-param name="profile" select="$profile"/>
        </xsl:call-template>
        <xsl:call-template name="result-details">
            <xsl:with-param name="testresult" select="$testresult"/>
            <xsl:with-param name="benchmark" select="$benchmark"/>
            <xsl:with-param name="profile" select="$profile"/>
        </xsl:call-template>
    </div></div>

    <xsl:call-template name="xccdf-report-footer"/>

    </body>
    </html>
</xsl:template>

</xsl:stylesheet>
