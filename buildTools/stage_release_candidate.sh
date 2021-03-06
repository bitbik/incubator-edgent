#!/bin/sh

################################################################################
##
##  Licensed to the Apache Software Foundation (ASF) under one or more
##  contributor license agreements.  See the NOTICE file distributed with
##  this work for additional information regarding copyright ownership.
##  The ASF licenses this file to You under the Apache License, Version 2.0
##  (the "License"); you may not use this file except in compliance with
##  the License.  You may obtain a copy of the License at
##
##      http://www.apache.org/licenses/LICENSE-2.0
##
##  Unless required by applicable law or agreed to in writing, software
##  distributed under the License is distributed on an "AS IS" BASIS,
##  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##  See the License for the specific language governing permissions and
##  limitations under the License.
##
################################################################################

set -e

# Copy the build generated artifacts to a working copy of the 
# ASF subversion Edgent Release Candidate repository.
# If the user hasn't already setup a svn checkout the script offers to do it
# to ~/svn/dist.apache.org/repos/dist/dev/incubator/edgent.
# The user is provided with the svn command to commit the changes to the repo.
# Prompts before taking actions.
#
# Run from the root of the release management git clone.
# Defaults bundle-dir to target/checkout/target (mvn release:perform generated)


. `dirname $0`/common.sh

setUsage "`basename $0` <rc-num> [bundle-dir]"
handleHelp "$@"

requireArg "$@"
RC_NUM=$1; shift
checkRcNum ${RC_NUM} || usage "Not a release candidate number \"${RC_NUM}\""
RC_DIRNAME="rc${RC_NUM}"

# default BUNDLE_DIR is in common.sh
if [ $# -gt 0 ]; then
  BUNDLE_DIR=$1; shift
fi

noExtraArgs "$@"

SVN_DEV_EDGENT=~/svn/dist.apache.org/repos/dist/dev/incubator/edgent

checkBundleDir || die "Bundle directory '${BUNDLE_DIR}' does not exist" 

# checkUsingMgmtCloneWarn || confirm "Proceed using this clone?" || exit

# Get the X.Y.Z version from the bundle name
VER=`getEdgentVer bundle`
VER_DIRNAME=${VER}-incubating

RC_TAG=`getReleaseTag ${VER} ${RC_NUM}`

echo "Base svn Edgent dev directory to stage to: ${SVN_DEV_EDGENT}"
confirm "Proceed with staging for ${RC_TAG}?" || exit

# with the switch to the maven release plugin, only the .asc file
# is generated, not the checksum files.
# generate/update them now.
${BUILDTOOLS_DIR}/make_checksums.sh ${BUNDLE_DIR}

# Offer to do svn checkout if needed
if [ ! -d ${SVN_DEV_EDGENT}/.svn ]; then
  echo "${SVN_DEV_EDGENT}/.svn: No such file or directory"
  confirm "Setup that svn checkout now?" || exit
  echo "Be patient while downloading..."
  SVN_PARENT_DIR=`dirname ${SVN_DEV_EDGENT}`
  (set -x; mkdir -p ${SVN_PARENT_DIR}) 
  (set -x; cd ${SVN_PARENT_DIR}; svn co ${EDGENT_ASF_SVN_RC_URL} --depth empty)
  (set -x; svn update ${SVN_DEV_EDGENT}/KEYS)
fi

SVN_VER_DIR=${SVN_DEV_EDGENT}/${VER_DIRNAME}
SVN_RC_DIR=${SVN_VER_DIR}/${RC_DIRNAME}

echo ""
echo "Checking the svn status of ${SVN_DEV_EDGENT}:"
(cd ${SVN_DEV_EDGENT}; svn status)
echo
confirm "Is the svn status ok to continue (blank / nothing reported) ?" || exit

echo ""
echo "Updating KEYS..."
(set -x; svn update ${SVN_DEV_EDGENT}/KEYS)

# Create this structure in the Edgent dev svn tree
#
# KEYS
# X.Y.Z-incubating
#   rc<n>
#     README
#     RELEASE_NOTES
#     source bundles and signatures

echo ""
echo "Copying artifacts to ${SVN_DEV_EDGENT}..." 

mkdir -p ${SVN_DEV_EDGENT}
cp KEYS ${SVN_DEV_EDGENT}
# svn add KEYS  # adding was a one-time event

if [ ! -d ${SVN_VER_DIR} ]; then
  mkdir -p ${SVN_VER_DIR}
fi

mkdir -p ${SVN_RC_DIR}
cp README ${SVN_RC_DIR}
cp RELEASE_NOTES ${SVN_RC_DIR}
cp ${BUNDLE_DIR}/apache-edgent-*-source-release.* ${SVN_RC_DIR}

if [ ! `svn info --show-item url ${SVN_VER_DIR} 2>/dev/null` ]; then
  (set -x; svn add ${SVN_VER_DIR})
else
  (set -x; svn add ${SVN_RC_DIR})
fi

echo
(set -x; svn status ${SVN_DEV_EDGENT})

echo
echo "If you choose not to proceed, you can later run the following to commit the changes:"
echo "    (cd ${SVN_DEV_EDGENT}; svn commit -m \"Add Apache Edgent ${VER}-incubating/rc${RC_NUM}\")"
confirm "Proceed to commit the changes?" || exit
(set -x; cd ${SVN_DEV_EDGENT}; svn commit -m "Add Apache Edgent ${VER}-incubating/rc${RC_NUM}")

echo
echo "The KEYS and ${RC_TAG} have been staged to ${EDGENT_ASF_SVN_RC_URL}"