# t/01_main.t - main testing file (for Gpx.pm)
use strict;
use warnings;

use Test::More tests => 5;
use Geo::Gpx;
use File::Temp qw/ tempfile tempdir /;
use Cwd qw(cwd abs_path);

my $cwd     = abs_path( cwd() );
my $tmp_dir = tempdir( CLEANUP => 1 );

my $href_chez_andy = { lat => 54.786989, lon => -2.344214, ele => 512, time => 1164488503, magvar => 0, geoidheight => 0, name => 'My house & home', cmt => 'Where I live', desc => '<<Chez moi>>', src => 'Testing', link => { href => 'http://hexten.net/', text => 'Hexten', type => 'Blah' }, sym => 'Flag, Green', type => 'unknown', fix => 'dgps', sat => 3, hdop => 10, vdop => 10, pdop => 10, ageofdgpsdata => 45, dgpsid => 247 };

my $href_chez_pat  = { lat => 45.93789, lon => -75.85077, lon => -2.344214, ele => 550, time => 1167813923, magvar => 0, geoidheight => 0, name => 'Atop Radar Road', cmt => 'This key is cmt', desc => '<<This key is desc>>', src => 'Testing', sym => 'pin', type => 'unknown', fix => 'dgps', sat => 3, hdop => 10, vdop => 10, pdop => 10, ageofdgpsdata => 54, dgpsid => 247 };

my $href_chez_kaz = { lat => 45.94636, lon => -76.01154, 'sym' => 'Parking Area' };

my $o  = Geo::Gpx->new();
isa_ok ($o,  'Geo::Gpx');

$o->waypoints(  [ $href_chez_andy, $href_chez_pat ] );
$o->add_waypoint( $href_chez_kaz );

#
# Section A - Constructor

# new(): from filename (file with only waypoints)
my $fname_wpt1 = 't/larose_wpt.gpx';
my $o_wpt_only1 = Geo::Gpx->new( input => "$fname_wpt1" );
isa_ok ($o_wpt_only1,  'Geo::Gpx');

# new(): from filename (file with only trackpoints)
my $fname_trk1 = 't/larose_trk1.gpx';
my $o_trk_only1 = Geo::Gpx->new( input => "$fname_trk1" );
isa_ok ($o_trk_only1,  'Geo::Gpx');
my $fname_trk2 = 't/larose_trk2.gpx';
my $o_trk_only2 = Geo::Gpx->new( input => "$fname_trk2" );
isa_ok ($o_trk_only2,  'Geo::Gpx');

# NextSteps: create a new empty gpx file, add the waypoints, add a track, then add another track (do we have a method to add another track like add_waypoint()

#
# Section B - Object Methods

# add_waypoint(): will likely rename waypoints_add()
my %point = ( lat => 54.786989, lon => -2.344214, ele => 512, time => 1164488503, name => 'My house', desc => 'There\'s no place like home' );
my $pt = Geo::Gpx::Point->new( %point );
$pt->sym('Triangle, Blue');
$o->add_waypoint( $pt );

# tracks_add(): test also with aref's
$DB::single = 1;
my $track1 = $o_trk_only1->tracks( 1 );
my $track2 = $o_trk_only2->tracks( 1 );
$o_wpt_only1->tracks_add( $track1, name => 'My first track' );
$o_wpt_only1->tracks_add( $track2, name => 'A second track' );
my $get_track = $o_wpt_only1->tracks( name => 'A second track' );

# save(): a few saves
$o->set_wd( $tmp_dir );
$o->save( filename => 'test_save.gpx', force => 1);
$o->set_wd( '-' );
$o_wpt_only1->set_wd( $tmp_dir );
$o_wpt_only1->save( filename => 'test_save_wpt_and_track.gpx', force => 1);
$o_wpt_only1->set_wd( '-' );

# save() - new instance based on saved file
my $saved_then_read  = Geo::Gpx->new( input => 't/test.gpx');
isa_ok ($saved_then_read,  'Geo::Gpx');

$DB::single = 1;
print "so debugger doesn't exit\n";

