#!/usr/bin/env bash

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# IPP - jsn - veřejné testy - 2011/2012
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Činnost: 
# - vytvoří výstupy studentovy úlohy v daném interpretu na základě sady testů
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

TASK=jsn
INTERPRETER=perl
EXTENSION=pl
#INTERPRETER=python3
#EXTENSION=py

# cesta pro ukládání chybového výstupu studentského skriptu
LOCAL_OUT_PATH="."  
LOG_PATH="."


# test01: prazdny objekt, vystupem jen hlavicka; Expected output: test01.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test01.jsn --output=test01.xml 2> test01.err
echo -n $? > test01.!!!

# test02: prazdny objekt, vystupem je prazdny XML (hlavicka vynechana); Expected output: test02.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test02.jsn --output=test02.xml -n -r="koren" 2> test02.err
echo -n $? > test02.!!!

# test03: jednoduchy objekt, neobaluji (=>nevalidni XML vsak nevadi); Expected output: test03.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION  -n --input=test03.jsn --output=test03.xml 2> test03.err
echo -n $? > test03.!!!

# test04: jednoduchy objekt obalen a vypustena hlavicka; Expected output: test04.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION  --input=test04.jsn --output=test04.xml -n -r="koren" 2> test04.err
echo -n $? > test04.!!!

# test05: jednoduchy objekt obalen a vypustena hlavicka, nevyznamne --array-name; Expected output: test05.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test05.jsn -n -r="koren" --array-name="pole" --output=test05.xml 2> test05.err
echo -n $? > test05.!!!

# test06: globalni pole, literaly transformuji na elementy; Expected output: test06.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test06.jsn --output=test06.xml -l 2> test06.err
echo -n $? > test06.!!!

# test07: globalni pole s parametry -r a --item-name, velikost pole; Expected output: test07.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION -r="root" --item-name="pól" --input="test07.jsn" --output="test07.xml" -a 2> test07.err
echo -n $? > test07.!!!

# test08: objekt s polem uvnitr; indexace polozek pole; neobsahuje retezcovy literal, takze se -s neuplatni; Expected output: test08.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test08.jsn --output=test08.xml -n -s --start=0 -t 2> test08.err
echo -n $? > test08.!!!

# test09: slozitejsi objekt (generuje nevalidni XML; -s => retezce jsou transformovany na textove elementy misto atributu); Expected output: test09.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test09.jsn --output=test09.xml -n -s 2> test09.err
echo -n $? > test09.!!!

# test10: vstup neni formatovan, obalujici element obsahuje pomlcku (vznika validni element); Expected output: test10.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test10.jsn --output=test10.xml -r="tešt-élěm" 2> test10.err
echo -n $? > test10.!!!

# test11: specialni znaky v hodnote (-c); Expected output: test11.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test11.jsn --output=test11.xml -c -l -r="rOOt" 2> test11.err
echo -n $? > test11.!!!

# test12: specialní znaky i diakritika v hodnotě (-c), dále -r a -s; Expected output: test12.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION --input=test12.jsn --output=test12.xml -c -r=root -s 2> test12.err
echo -n $? > test12.!!!

# test13: komplexni priklad kombinace parametru; Expected output: test13.xml; Expected return code: 0
$INTERPRETER $TASK.$EXTENSION -a --input=test13.jsn -l --output=test13.xml -r="root" -s --start="2" --index-items 2> test13.err 
echo -n $? > test13.!!!

# test14: chybny element i po nahrazeni pomlckami; Expected output: test14.xml; Expected return code: 51
$INTERPRETER $TASK.$EXTENSION --input=test14.jsn --output=test14.xml -r="root" 2> test14.err
echo -n $? > test14.!!!

# test15: chyne jmeno elementu v prikazove radce; Expected output: test15.xml; Expected return code: 50
$INTERPRETER $TASK.$EXTENSION --input=test15.jsn --output=test15.xml --array-name="b<a>d" 2> test15.err
echo -n $? > test15.!!!

