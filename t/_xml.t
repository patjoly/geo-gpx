# t/_xml.t - test _xml(), _tag(), _enc(), all methods called by xml()
use strict;
use warnings;

use Test::More tests => 7;
use Geo::Gpx;
use File::Temp qw/ tempfile tempdir /;
use Cwd qw(cwd abs_path);

my $cwd     = abs_path( cwd() );
my $tmp_dir = tempdir( CLEANUP => 1 );

my $o  = Geo::Gpx->new( input => 't/larose_wpt.gpx');
isa_ok ($o,  'Geo::Gpx');

# just a temporary call to xml() -- so we can put breakpoint in *.pm and see what the argument are where for calls we want to test
# $o->xml();

#
# _tag() -- as called by _xml()

#      . with a non-empty href
my $uc   = '<>&"';        # same as the default ($unsafe_chars_default), could test with other values for $uc
my $tag  = 'wpt';
my $attr = { 'lat' => 45.376138994470239, 'lon' => -75.242366977035999 };
my @cont = ( "\n", "<ele>73</ele>\n", "<name>LP1</name>\n", "<cmt>Larose P1 - Limoges' Parking</cmt>\n", "<desc>Larose P1 - Limoges - Stationnement &#x26; début des trails</desc>\n", "<sym>Flag, Green</sym>\n", "<extensions>SymbolAndName</extensions>\n" );
my $expect_tag = "<wpt lat=\"45.3761389944702\" lon=\"-75.242366977036\">\n<ele>73</ele>\n<name>LP1</name>\n<cmt>Larose P1 - Limoges' Parking</cmt>\n<desc>Larose P1 - Limoges - Stationnement &#x26; début des trails</desc>\n<sym>Flag, Green</sym>\n<extensions>SymbolAndName</extensions>\n</wpt>\n";
my $return_tag = Geo::Gpx::_tag( $uc, $tag, $attr, @cont );
is($return_tag, $expect_tag,            "    _tag(): as called by _xml() with a non-empty href");

#      . with an empty href
$tag  = 'desc';
@cont = 'Larose P1 - Limoges';
$expect_tag = "<desc>Larose P1 - Limoges</desc>\n";
$return_tag = Geo::Gpx::_tag( $uc, $tag, {}, @cont );
is($return_tag, $expect_tag,            "    _tag(): as called by _xml() with an empty href");

#
# _tag() -- as called by itself

#      . with an empty href
$tag = 'name';
my $value = 'α β\' è γ';
$expect_tag = "<name>α β' è γ</name>\n";
$return_tag = Geo::Gpx::_tag( $uc, $tag, {}, Geo::Gpx::_enc( $value, $uc ) );
is($return_tag, $expect_tag,            "    _tag(): as called by itself with an empty href");

#
# _xml() -- as called by xml()

#      . with a href
my $name = 'wpt';
$value = {
   'cmt' => 'Larose P1 - Limoges\' Parking',
   'desc' => 'Larose P1 - Limoges - Stationnement & début des trails',
   'ele' => 73,
   'extensions' => 'SymbolAndName',
   'lat' => 45.376138994470239,
   'lon' => '-75.242366977035999',
   'name' => 'LP1',
   'sym' => 'Flag, Green'
   };
my $expect__xml = "<wpt lat=\"45.3761389944702\" lon=\"-75.242366977035999\">\n<ele>73</ele>\n<name>LP1</name>\n<cmt>Larose P1 - Limoges' Parking</cmt>\n<desc>Larose P1 - Limoges - Stationnement &#x26; début des trails</desc>\n<sym>Flag, Green</sym>\n<extensions>SymbolAndName</extensions>\n</wpt>\n";
my $return__xml = $o->_xml( $uc, $name, $value );
is($return__xml, $expect__xml,            "    _xml(): as called by xml() with a href as \$value");

#      . with an aref
$name = 'wpt';
$value = [ $o->waypoints_search( desc => qr/Limoges/ ) ];
my $name_map = { 'waypoints' => 'wpt' };
$expect__xml = "<wpt lat=\"45.376138994470239\" lon=\"-75.242366977035999\">\n<ele>73</ele>\n<name>LP1</name>\n<cmt>Larose P1 - Limoges</cmt>\n<desc>Larose P1 - Limoges</desc>\n<sym>Flag, Green</sym>\n<extensions>SymbolAndName</extensions>\n</wpt>\n<wpt lat=\"45.373264001682401\" lon=\"-75.23972500115633\">\n<ele>99</ele>\n<name>LP7</name>\n<cmt>Larose P7 - Limoges</cmt>\n<desc>Larose P7 - Limoges</desc>\n<sym>Flag, Green</sym>\n<extensions>SymbolAndName</extensions>\n</wpt>\n";
$return__xml = $o->_xml( $uc, $name, $value, $name_map );
is($return__xml, $expect__xml,            "    _xml(): as called by xml() with an aref as \$value");

#      . with a scalar
$name  = 'desc';
$value = 'Larose P1 - Limoges';
$expect__xml= "<desc>Larose P1 - Limoges</desc>\n";
$return__xml = $o->_xml( $uc, $name, $value );
is($return__xml, $expect__xml,            "    _xml(): as called by _xml() with a scalar as \$value");

print "so debugger doesn't exit\n";
