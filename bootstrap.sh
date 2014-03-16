#!/bin/bash
##################################################
#
# vim: ai:ts=4:sw=4:noet:sts=4:ft=sh
#
# Copyright 2013, Steven Koeberich (nemesissre@gmail.com)
#
# Title:			Dinner
# Author:			Steven "NemesisRE" Koeberich
# Author URL:		https://nrecom.net
# Contributors:		ToeiRei
# Creation Date:	20131117
# Version:			2.0
# Description:		Builds Roms automatically
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at (http://www.gnu.org/licenses/) for
# more details.


#set -x

if [[ ${EUID} -eq 0 ]]; then
	echo "For your own safety, do not run as root user!"
	exit 1
fi

### Install dinner ###
if [ $(which git) ]; then
	$(which git) clone https://github.com/NemesisRE/dinner.git ${HOME}/.dinner
else
	echo "Could not find git executable, please install git and try again."
fi

# Source .dinner in .bashrc
grep -xq 'source ${HOME}/.dinner/helper/dinner_completion.sh' ${HOME}/.bashrc || printf '\nsource ${HOME}/.dinner/helper/dinner_completion.sh"' >> ${HOME}/.bashrc
grep -xq 'export PATH=$PATH:${HOME}/.dinner/bin' ${HOME}/.bashrc || printf '\nexport PATH=$PATH:${HOME}/.dinner/bin' >> ${HOME}/.bashrc

echo "Please relog or run \"source ${HOME}/.bashrc\" then you can start dinner by typing \"dinner\""
