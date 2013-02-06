#!/bin/sh

# FIXME final archive
#tar -cvzf xpacne00-JSN.tgz JSN-doc.pdf jsn.pl
#
#exit

my="./test_ref_my/"
ref="./test_ref/"
cp ./jsn.pl "$my" || exit 1
cd "$my" || exit 1
rm *.xml *.err
mksh ./_stud_tests.sh || exit 1
cd ../"$ref" || exit 1
for f in *.xml; do
  diff -urN "$f" "../$my$f"
  echo
done

exit

echo 00 empty array -r
perl $1 -r='x235hovno' <<XYZ
[]
XYZ
#<array/>
echo --$?----; echo

echo 01 empty hash -r
perl $1 -r=root <<XYZ
{}
XYZ
echo --$?----; echo

echo 02 empty FAIL -r
perl $1 -r=root <<XYZ
"x" : "y"
XYZ
echo --$?----; echo

echo 03 empty hash in array
perl $1 <<XYZ
[ [ [], {}, "x", { "a": "b", "c": "d" } ], { "y": {}, "z": [], "b": "c" }, "nic" ]
XYZ
#<array>
#  <array>
#    <array/>
#    #nothing
#    <item value="x"/>
#    <a value="b"/>
#    <c>    # tohle je bez $arg_s a bez $arg_i
#      d
#    </c>
#  </array>
#  #anonymni hash NEMA zadne uzavirani
#  <y/>
#  <z>
#    <array/>
#  </z>
#  <b value="c"/>
#  <item value="nic"/>
#</array>
echo --$?----; echo

echo 04 non-empty hash in hash
perl $1 <<XYZ
{ "a": "b", "c": { "d": "e", "f": "g" }, "h": "i" }
XYZ
#<a>
#  b
#</a>
#<c>
#  <d>
#    e
#  </d>
#  <f>
#    g
#  </f>
#</c>
#<h>
#  i
#</h>
echo --$?----; echo

echo 05 true false null
perl $1 <<XYZ
[ true, false, null ]
XYZ
echo --$?----; echo

echo 06 \"true\" \"false\" \"null\"
perl $1 <<XYZ
[ "true", "false", "null" ]
XYZ
echo --$?----; echo
