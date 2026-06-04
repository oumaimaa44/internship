#**********************************************************************#
#                               AsteRISC                               #
#**********************************************************************#
#
# Copyright (C) 2022 Jonathan Saussereau
#
# This file is part of AsteRISC.
# AsteRISC is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# AsteRISC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with AsteRISC. If not, see <https://www.gnu.org/licenses/>.
#

import re

def find_and_replace( ptrn, s, subs ):
  for m in ptrn.finditer( s ):
    grp = m.group( 0 )
    if grp in subs:
      pad = ""
      #  NYI : multiple lists in one line
      if type( subs[grp] ) is list: 
        pad = '\n' + ' ' * m.start()
      s = s.replace( grp, pad.join( subs[grp] ) )
  return s

def render_lines( lines, subs ):
  rlines  = []
  ptrn = re.compile( r"\${([A-Za-z_][A-Za-z_0-9]*)}" ) # ${}
  pevl = re.compile( r"\%\beval\b\((.*?)\)" ) # %eval
  for l in lines:
    l = find_and_replace( ptrn, l, subs )
    for m in pevl.finditer( l ):
      l = l.replace( m.group( 0 ), str( eval( m.group( 1 ) ) ) )
    rlines.append( l )
  return rlines

def render_to_file( fni, fno, subs ):
  with open( fni, 'r' ) as fi:
    a = render_lines( fi.readlines(), subs )
    with open( fno, 'w' ) as fo:
      for line in a:
        fo.write( "{:s}".format( line ) )

def check_file( fn ):
  try:
    f = open( fn, 'r' )
  except Exception as e:
    print( e )
    return False
  return True
