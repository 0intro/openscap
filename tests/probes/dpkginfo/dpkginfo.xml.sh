#!/usr/bin/env bash

DPKG_A_NAME=$1
DPKG_A_ARCH=$2
DPKG_A_EPOCH=$3
DPKG_A_VERSION=$4
DPKG_A_RELEASE=$5
DPKG_A_EVR=$6

DPKG_B_NAME=$7
DPKG_B_ARCH=$8
DPKG_B_EPOCH=$9
DPKG_B_VERSION=${10}
DPKG_B_RELEASE=${11}
DPKG_B_EVR=${12}

cat <<EOF
<?xml version="1.0"?>
<oval_definitions xmlns:oval-def="http://oval.mitre.org/XMLSchema/oval-definitions-5" xmlns:oval="http://oval.mitre.org/XMLSchema/oval-common-5" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:ind-def="http://oval.mitre.org/XMLSchema/oval-definitions-5#independent" xmlns:unix-def="http://oval.mitre.org/XMLSchema/oval-definitions-5#unix" xmlns:lin-def="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5" xsi:schemaLocation="http://oval.mitre.org/XMLSchema/oval-definitions-5#unix unix-definitions-schema.xsd http://oval.mitre.org/XMLSchema/oval-definitions-5#independent independent-definitions-schema.xsd http://oval.mitre.org/XMLSchema/oval-definitions-5#linux linux-definitions-schema.xsd http://oval.mitre.org/XMLSchema/oval-definitions-5 oval-definitions-schema.xsd http://oval.mitre.org/XMLSchema/oval-common-5 oval-common-schema.xsd">

      <generator>
            <oval:product_name>dpkginfo</oval:product_name>
            <oval:product_version>1.0</oval:product_version>
            <oval:schema_version>5.11.1</oval:schema_version>
            <oval:timestamp>2024-01-01T00:00:00-00:00</oval:timestamp>
      </generator>

  <definitions>

    <definition class="compliance" version="1" id="oval:1:def:1"> <!-- comment="true" -->
      <metadata>
        <title></title>
        <description></description>
      </metadata>
      <criteria>
        <criterion test_ref="oval:1:tst:1"/>
      </criteria>
    </definition>

    <definition class="compliance" version="1" id="oval:1:def:2"> <!-- comment="true" -->
      <metadata>
        <title></title>
        <description></description>
      </metadata>
      <criteria>
        <criterion test_ref="oval:1:tst:2"/>
      </criteria>
    </definition>

    <definition class="compliance" version="1" id="oval:1:def:3"> <!-- comment="true" -->
      <metadata>
        <title></title>
        <description></description>
      </metadata>
      <criteria>
        <criterion test_ref="oval:1:tst:3"/>
      </criteria>
    </definition>

    <definition class="compliance" version="1" id="oval:1:def:4"> <!-- comment="false" -->
      <metadata>
        <title></title>
        <description></description>
      </metadata>
      <criteria>
        <criterion test_ref="oval:1:tst:4"/>
      </criteria>
    </definition>

    <definition class="compliance" version="1" id="oval:1:def:5"> <!-- comment="true" -->
      <metadata>
        <title></title>
        <description></description>
      </metadata>
      <criteria>
        <criterion test_ref="oval:1:tst:5"/>
      </criteria>
    </definition>

    <definition class="compliance" version="1" id="oval:1:def:6"> <!-- comment="true" -->
      <metadata>
        <title></title>
        <description></description>
      </metadata>
      <criteria>
        <criterion test_ref="oval:1:tst:6"/>
      </criteria>
    </definition>

    <definition class="compliance" version="1" id="oval:1:def:7"> <!-- comment="true" -->
      <metadata>
        <title></title>
        <description></description>
      </metadata>
      <criteria>
        <criterion test_ref="oval:1:tst:7"/>
      </criteria>
    </definition>

  </definitions>

  <tests>

    <!-- Package A exists, stateless, check=all -->
    <dpkginfo_test version="1" id="oval:1:tst:1" check="all" comment="true" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <object object_ref="oval:1:obj:1"/>
    </dpkginfo_test>

    <!-- Nonexistent package, none_exist -->
    <dpkginfo_test version="1" id="oval:1:tst:2" check_existence="none_exist" check="all" comment="true" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <object object_ref="oval:1:obj:3"/>
    </dpkginfo_test>

    <!-- Package A with matching state -->
    <dpkginfo_test version="1" id="oval:1:tst:3" check="all" comment="true" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <object object_ref="oval:1:obj:1"/>
      <state state_ref="oval:1:ste:1"/>
    </dpkginfo_test>

    <!-- Package A with wrong state -->
    <dpkginfo_test version="1" id="oval:1:tst:4" check="all" comment="false" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <object object_ref="oval:1:obj:1"/>
      <state state_ref="oval:1:ste:3"/>
    </dpkginfo_test>

    <!-- Package B exists, stateless -->
    <dpkginfo_test version="1" id="oval:1:tst:5" check="all" comment="true" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <object object_ref="oval:1:obj:2"/>
    </dpkginfo_test>

    <!-- Package B with matching state -->
    <dpkginfo_test version="1" id="oval:1:tst:6" check="all" comment="true" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <object object_ref="oval:1:obj:2"/>
      <state state_ref="oval:1:ste:2"/>
    </dpkginfo_test>

    <!-- Nonexistent package, none_exist -->
    <dpkginfo_test version="1" id="oval:1:tst:7" check_existence="none_exist" check="all" comment="true" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <object object_ref="oval:1:obj:3"/>
    </dpkginfo_test>

  </tests>

  <objects>

    <dpkginfo_object version="1" id="oval:1:obj:1" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <name>${DPKG_A_NAME}</name>
    </dpkginfo_object>

    <dpkginfo_object version="1" id="oval:1:obj:2" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <name>${DPKG_B_NAME}</name>
    </dpkginfo_object>

    <dpkginfo_object version="1" id="oval:1:obj:3" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <name>nonexistent_package_xyzzy</name>
    </dpkginfo_object>

  </objects>

  <states>

    <dpkginfo_state version="1" id="oval:1:ste:1" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <name>${DPKG_A_NAME}</name>
      <arch>${DPKG_A_ARCH}</arch>
      <version>${DPKG_A_VERSION}</version>
    </dpkginfo_state>

    <dpkginfo_state version="1" id="oval:1:ste:2" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <name>${DPKG_B_NAME}</name>
      <arch>${DPKG_B_ARCH}</arch>
    </dpkginfo_state>

    <dpkginfo_state version="1" id="oval:1:ste:3" xmlns="http://oval.mitre.org/XMLSchema/oval-definitions-5#linux">
      <name>invalid</name>
      <version>0.0.0.0.0</version>
    </dpkginfo_state>

  </states>

</oval_definitions>
EOF
