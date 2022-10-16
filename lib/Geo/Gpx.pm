package Geo::Gpx;

use warnings;
use strict;

our $VERSION = '1.04';

use Carp;
use DateTime::Format::ISO8601;
use DateTime;
use HTML::Entities qw( encode_entities encode_entities_numeric );
use Scalar::Util qw( blessed );
use Time::Local;
use XML::Descent;
use File::Basename;
use Cwd qw(cwd abs_path);
use Geo::Gpx::Point;

=encoding utf8

=head1 NAME

Geo::Gpx - Create and parse GPX files

=head1 SYNOPSIS

  my ($gpx, $waypoints, $track);

  # From an open file or an XML string
  $gpx = Geo::Gpx->new( input => $fh );
  $gpx = Geo::Gpx->new( xml => $xml );

  my $waypoints = $gpx->waypoints();
  my $tracks    = $gpx->tracks();

=head1 DESCRIPTION

C<Geo::Gpx> supports the parsing and generation of GPX data. GPX 1.0 and 1.1 are supported.

=cut

# Values that are encoded as attributes
my %AS_ATTR = (
  wpt   => qr{^lat|lon$},
  rtept => qr{^lat|lon$},
  trkpt => qr{^lat|lon$},
  email => qr{^id|domain$},
  link  => qr{^href$}
);

my %KEY_ORDER = (
  wpt => [
    qw(
     ele time magvar geoidheight name cmt desc src link sym type fix
     sat hdop vdop pdop ageofdgpsdata dgpsid extensions
     )
  ],
);

# Map hash keys to GPX names
my %XMLMAP = (
  waypoints => { waypoints => 'wpt' },
  routes    => {
    routes => 'rte',
    points => 'rtept'
  },
  tracks => {
    tracks   => 'trk',
    segments => 'trkseg',
    points   => 'trkpt'
  }
);

my @META;
my @ATTR;

BEGIN {
  @META = qw( name desc author time keywords copyright link );
  @ATTR = qw( tracks routes version );

  # Generate accessors
  for my $attr ( @META, @ATTR ) {
    no strict 'refs';
    *{ __PACKAGE__ . '::' . $attr } = sub {
      my $self = shift;
      $self->{$attr} = shift if @_;
      return $self->{$attr};
    };
  }
}

sub _parse_time {
  my ( $self, $str ) = @_;
  my $dt = DateTime::Format::ISO8601->parse_datetime( $str );
  return $self->{use_datetime} ? $dt : $dt->epoch;
}

sub _format_time {
  my ( $self, $tm, $legacy ) = @_;
  unless ( blessed $tm && $tm->can( 'strftime' ) ) {
    return $self->_format_time(
      DateTime->from_epoch(
        epoch     => $tm,
        time_zone => 'UTC'
      ),
      $legacy
    );
  }

  my $ts = $tm->strftime(
    $legacy
    ? '%Y-%m-%dT%H:%M:%S.%7N%z'
    : '%Y-%m-%dT%H:%M:%S%z'
  );
  $ts =~ s/(\d{2})$/:$1/;
  return $ts;
}

# For backwards compatibility
sub _init_legacy {
  my $self = shift;

  $self->{keywords} = [qw(cache geocache groundspeak)];
  $self->{author}   = {
    name  => 'Groundspeak',
    email => {
      id     => 'contact',
      domain => 'groundspeak.com'
    }
  };
  $self->{desc}   = 'GPX file generated by Geo::Gpx';
  $self->{schema} = [
    qw(
     http://www.groundspeak.com/cache/1/0
     http://www.groundspeak.com/cache/1/0/cache.xsd
     )
  ];

  require Geo::Cache;

  $self->{handler} = {
    create => sub {
      return Geo::Cache->new( @_ );
    },
    time => sub {
      return $self->_format_time( $_[0], 1 );
    },
  };
}

sub _init_shiny_new {
  my ( $self, $args ) = @_;

  $self->{use_datetime} = $args->{use_datetime} || 0;

  $self->{schema} = [];

  $self->{handler} = {
    create => sub {
      return {@_};
    },
    time => sub {
      return $self->_format_time( $_[0], 0 );
    },
  };
}

=head2 Constructor

=over 4

=item new( args [, use_datetime => $bool, work_dir => $working_directory )

Create and return a new C<Geo::Gpx> instance based on an array of points that can each be constructed as L<Geo::Gpx::Point> objects or with a supplied XML file handle or XML string.

If C<use_datetime> is set to true, time values in parsed GPX will be L<DateTime> objects rather than epoch times. (This option may be disabled in the future in favour of a method that can return a L<DateTime> object from a specified point.)

C<work_dir> or C<wd> for short can be set to specify where to save any working files (such as with the save_laps() method). The module never actually L<chdir>'s, it just keeps track of where the user wants to save files (and not have to type filenames with path each time), hence it is always defined.

The working directory can be supplied as a relative (to L<Cwd::cwd>) or absolute path but is internally stored by C<set_wd()> as a full path. If C<work_dir> is ommitted, it is set based on the path of the I<$filename> supplied or the current working directory if the constructor is called with an XML string or a filehandle.


=back

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, $class );

  # CORE::time because we have our own time method.
  $self->{time} = CORE::time();

  # Has to handle same calling convention as previous
  # version.
  if ( blessed $args[0] && $args[0]->isa( 'Geo::Cache' ) ) {
    $self->_init_legacy();
    $self->{waypoints} = \@args;
  }
  elsif ( @args % 2 == 0 ) {
    my %args = @args;
    $self->_init_shiny_new( \%args );

    if ( exists $args{input} ) {
        my ($fh, $arg);
        $arg = $args{input};
        $arg =~ s/~/$ENV{'HOME'}/ if $arg =~ /^~/;
        if (-f $arg) {
            open( $fh , '<', $arg ) or  die "can't open file $arg $!";
            $self->_parse( $fh );
            # Once I have copied that method
            $self->set_filename($arg);
        } else { $self->_parse( $args{input} ) }
    }
    elsif ( exists $args{xml} ) {
      $self->_parse( \$args{xml} );
    }
    $self->set_wd( $args{work_dir} || $args{wd} );
  }
  else {
    croak( "Invalid arguments" );
  }
  # Once I have copied that method, and capured that option above
  return $self;
}

# Not a method
sub _trim {
  my $str = shift;
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  $str =~ s/\s+/ /g;
  return $str;
}

sub _parse {
  my $self   = shift;
  my $source = shift;

  my $p = XML::Descent->new( { Input => $source } );

  $p->on(
    gpx => sub {
      my ( $elem, $attr ) = @_;

      $p->context( $self );

      my $version = $self->{version} = ( $attr->{version} || '1.0' );

      my $parse_deep = sub {
        my ( $elem, $attr ) = @_;
        my $ob = $attr;    # Get attributes
        $p->context( $ob );
        $p->walk();
        return $ob;
      };

      # Parse a point
      my $parse_point = sub {
        my ( $elem, $attr ) = @_;
        my $pt = $parse_deep->( $elem, $attr );
        return Geo::Gpx::Point->new( %{$pt} )
      };

      $p->on(
        '*' => sub {
          my ( $elem, $attr, $ctx ) = @_;
          $ctx->{$elem} = _trim( $p->text() );
        },
        time => sub {
          my ( $elem, $attr, $ctx ) = @_;
          my $tm = $self->_parse_time( _trim( $p->text() ) );
          $ctx->{$elem} = $tm if defined $tm;
        }
      );

      if ( _cmp_ver( $version, '1.1' ) >= 0 ) {

        # Handle 1.1 metadata
        $p->on(
          metadata => sub {
            $p->walk();
          },
          [ 'link', 'email', 'author' ] => sub {
            my ( $elem, $attr, $ctx ) = @_;
            $ctx->{$elem} = $parse_deep->( $elem, $attr );
          }
        );
      }
      else {

        # Handle 1.0 metadata
        $p->on(
          url => sub {
            my ( $elem, $attr, $ctx ) = @_;
            $ctx->{link}->{href} = _trim( $p->text() );
          },
          urlname => sub {
            my ( $elem, $attr, $ctx ) = @_;
            $ctx->{link}->{text} = _trim( $p->text() );
          },
          author => sub {
            my ( $elem, $attr, $ctx ) = @_;
            $ctx->{author}->{name} = _trim( $p->text() );
          },
          email => sub {
            my ( $elem, $attr, $ctx ) = @_;
            my $em = _trim( $p->text() );
            if ( $em =~ m{^(.+)\@(.+)$} ) {
              $ctx->{author}->{email} = {
                id     => $1,
                domain => $2
              };
            }
          }
        );
      }

      $p->on(
        bounds => sub {
          my ( $elem, $attr, $ctx ) = @_;
          $ctx->{$elem} = $parse_deep->( $elem, $attr );
        },
        keywords => sub {
          my ( $elem, $attr ) = @_;
          $self->{keywords}
           = [ map { _trim( $_ ) } split( /,/, $p->text() ) ];
        },
        wpt => sub {
          my ( $elem, $attr ) = @_;
          push @{ $self->{waypoints} }, $parse_point->( $elem, $attr );
        },
        [ 'trkpt', 'rtept' ] => sub {
          my ( $elem, $attr, $ctx ) = @_;
          push @{ $ctx->{points} }, $parse_point->( $elem, $attr );
        },
        rte => sub {
          my ( $elem, $attr ) = @_;
          my $rt = $parse_deep->( $elem, $attr );
          push @{ $self->{routes} }, $rt;
        },
        trk => sub {
          my ( $elem, $attr ) = @_;
          my $tk = {};
          $p->context( $tk );
          $p->on(
            trkseg => sub {
              my ( $elem, $attr ) = @_;
              my $seg = $parse_deep->( $elem, $attr );
              push @{ $tk->{segments} }, $seg;
            }
          );
          $p->walk();
          push @{ $self->{tracks} }, $tk;
        }
      );

      $p->walk();
    }
  );

  $p->walk();
}

=head2 Methods

=over 4

=item waypoints( \@waypoints )

Initialize waypoints based on an array reference containing either a list of L<Geo::Gpx::Point>s or hash references with fields that can be parsed by L<Geo::Gpx::Point>'s C<new()> constructor. See the later for the possible fields.

Returns the array reference of L<Geo::Gpx::Points> stored as waypoints.

=back

=cut

sub waypoints {
    my ($self, $aref) = @_;
    return $self->{waypoints} unless $aref;
    $self->{waypoints} = [];
    for my $pt (@$aref) {
        push @{ $self->{waypoints} }, Geo::Gpx::Point->new( %$pt )
    }
    return $self->{waypoints}
}

=over 4

=item add_waypoint( \%point [, \%point, … ] )

Add one or more waypoints. Each waypoint must be either a L<Geo::Gpx::Point> or a hash reference with fields that can be parsed by L<Geo::Gpx::Point>'s C<new()> constructor. See the later for the possible fields.

  %point = ( lat => 54.786989, lon => -2.344214, ele => 512, time => 1164488503, name => 'My house', desc => 'There\'s no place like home' );
  $gpx->add_waypoint( \%point );

    or

  $pt = Geo::Gpx::Point->new( %point );
  $gpx->add_waypoint( $pt );

Time values may either be an epoch offset or a L<DateTime>. If you wish to specify the timezone use a L<DateTime>. (This behaviour may change in the future.)

=back

=cut

sub add_waypoint {
  my $self = shift;

  for my $wpt ( @_ ) {
    eval { keys %$wpt };
    croak "waypoint argument must be a hash reference"
     if $@;

    croak "'lat' and 'lon' keys are mandatory in waypoint hash"
     unless exists $wpt->{lon} && exists $wpt->{lat};

    push @{ $self->{waypoints} }, Geo::Gpx::Point->new( %$wpt );
  }
}

# Not a method
sub _iterate_points {
  my $pts = shift || [];    # array ref

  unless ( defined $pts ) {
    return sub {
      return;
    };
  }

  my $max = scalar( @{$pts} );
  my $pos = 0;
  return sub {
    return if $pos >= $max;
    return $pts->[ $pos++ ];
  };
}

# Not a method
sub _iterate_iterators {
  my @its = @_;
  return sub {
    for ( ;; ) {
      return undef unless @its;
      my $next = $its[0]->();
      return $next if defined $next;
      shift @its;
    }
   }
}

=over 4

=item iterate_waypoints()

=item iterate_trackpoints()

=item iterate_routepoints()

Get an iterator for all of the waypoints, trackpoints, or routepoints in a C<Geo::Gpx> instance, as per the iterator chosen.

=cut

sub iterate_waypoints {
  my $self = shift;
  return _iterate_points( $self->{waypoints} );
}

sub iterate_routepoints {
  my $self = shift;

  my @iter = ();
  if ( exists( $self->{routes} ) ) {
    for my $rte ( @{ $self->{routes} } ) {
      push @iter, _iterate_points( $rte->{points} );
    }
  }

  return _iterate_iterators( @iter );

}

sub iterate_trackpoints {
  my $self = shift;

  my @iter = ();
  if ( exists( $self->{tracks} ) ) {
    for my $trk ( @{ $self->{tracks} } ) {
      if ( exists( $trk->{segments} ) ) {
        for my $seg ( @{ $trk->{segments} } ) {
          push @iter, _iterate_points( $seg->{points} );
        }
      }
    }
  }

  return _iterate_iterators( @iter );
}

=item iterate_points()

Get an iterator for all of the points in a C<Geo::Gpx> instance, including waypoints, trackpoints, and routepoints.

  my $iter = $gpx->iterate_points();
  while ( my $pt = $iter->() ) {
    print "Point: ", join( ', ', $pt->{lat}, $pt->{lon} ), "\n";
  }

=back

=cut

sub iterate_points {
  my $self = shift;

  return _iterate_iterators(
    $self->iterate_waypoints(),
    $self->iterate_routepoints(),
    $self->iterate_trackpoints()
  );
}

=over 4

=item bounds( $iterator )

Compute the bounding box of all the points in a C<Geo::Gpx> returning the result as a hash reference.

  my $gpx = Geo::Gpx->new( xml => $some_xml );
  my $bounds = $gpx->bounds();

returns a structure like this:

  $bounds = {
    minlat => 57.120939,
    minlon => -2.9839832,
    maxlat => 57.781729,
    maxlon => -1.230902
  };

C<$iterator> defaults to C<$self-E<gt>iterate_points> if not specified.

=cut

sub bounds {
  my ( $self, $iter ) = @_;
  $iter ||= $self->iterate_points;

  my $bounds = {};

  while ( my $pt = $iter->() ) {
    $bounds->{minlat} = $pt->{lat}
     if !defined $bounds->{minlat} || $pt->{lat} < $bounds->{minlat};
    $bounds->{maxlat} = $pt->{lat}
     if !defined $bounds->{maxlat} || $pt->{lat} > $bounds->{maxlat};
    $bounds->{minlon} = $pt->{lon}
     if !defined $bounds->{minlon} || $pt->{lon} < $bounds->{minlon};
    $bounds->{maxlon} = $pt->{lon}
     if !defined $bounds->{maxlon} || $pt->{lon} > $bounds->{maxlon};
  }

  return $bounds;
}

sub _enc {
  return encode_entities_numeric( $_[0] );
}

sub _tag {
  my $name = shift;
  my $attr = shift || {};
  my @tag  = ( '<', $name );

  # Sort keys so the tests can depend on hash output order
  for my $n ( sort keys %{$attr} ) {
    my $v = $attr->{$n};
    push @tag, ' ', $n, '="', _enc( $v ), '"';
  }

  if ( @_ ) {
    push @tag, '>', @_, '</', $name, ">\n";
  }
  else {
    push @tag, " />\n";
  }

  return join( '', @tag );
}

sub _xml {
  my $self     = shift;
  my $name     = shift;
  my $value    = shift;
  my $name_map = shift || {};

  my $tag = $name_map->{$name} || $name;
  my $is_geo_gpx_point = blessed $value and $value->isa('Geo::Gpx::Point');

  if ( blessed $value && $value->can( 'xml' ) ) {
    # Handles legacy Gpx::Cache objects that can
    # render themselves. Note that Gpx::Cache->xml
    # adds the <wpt></wpt> wrapper - so this won't
    # work correctly for trkpt and rtept
    return $value->xml( $name );
  }
  elsif ( defined( my $enc = $self->{encoder}->{$name} ) ) {
    return $enc->( $name, $value );
  }
  elsif ( ref $value eq 'HASH' or $is_geo_gpx_point ) {
    my $attr    = {};
    my @cont    = ( "\n" );
    my $as_attr = $AS_ATTR{$name};

    # Shallow copy so we can delete keys as we output them
    my %v = %{$value};
    for my $k ( @{ $KEY_ORDER{$name} || [] }, sort keys %v ) {
      if ( defined( my $vv = delete $v{$k} ) ) {
        if ( defined $as_attr && $k =~ $as_attr ) {
          $attr->{$k} = $vv;
        }
        else {
          push @cont, $self->_xml( $k, $vv, $name_map );
        }
      }
    }

    return _tag( $tag, $attr, @cont );
  }
  elsif ( ref $value eq 'ARRAY' ) {
    return join '',
     map { $self->_xml( $tag, $_, $name_map ) } @{$value};
  }
  else {
    return _tag( $tag, {}, _enc( $value ) );
  }
}

sub _cmp_ver {
  my ( $v1, $v2 ) = @_;
  my @v1 = split( /[.]/, $v1 );
  my @v2 = split( /[.]/, $v2 );

  while ( @v1 && @v2 ) {
    my $cmp = ( shift @v1 <=> shift @v2 );
    return $cmp if $cmp;
  }

  return @v1 <=> @v2;
}

=item xml( $version )

Generate and return an XML string representation of the instance.

If the version is omitted it defaults to the value of the C<version> attribute. Parsing a GPX document sets the version. If the C<version> attribute is unset defaults to 1.0.

=cut

sub xml {
  my $self = shift;
  my $version = shift || $self->{version} || '1.0';

  my @ret = ();

  push @ret, qq{<?xml version="1.0" encoding="utf-8"?>\n};

  $self->{encoder} = {
    time => sub {
      my ( $n, $v ) = @_;
      return _tag( $n, {}, _enc( $self->{handler}->{time}->( $v ) ) );
    },
    keywords => sub {
      my ( $n, $v ) = @_;
      return _tag( $n, {}, _enc( join( ', ', @{$v} ) ) );
     }
  };

  # Limit to the latest version we know about
  if ( _cmp_ver( $version, '1.1' ) >= 0 ) {
    $version = '1.1';
  }
  else {

    # Modify encoder
    $self->{encoder}->{link} = sub {
      my ( $n, $v ) = @_;
      my @v = ();
      push @v, $self->_xml( 'url', $v->{href} )
       if exists( $v->{href} );
      push @v, $self->_xml( 'urlname', $v->{text} )
       if exists( $v->{text} );
      return join( '', @v );
    };
    $self->{encoder}->{email} = sub {
      my ( $n, $v ) = @_;
      if ( exists( $v->{id} ) && exists( $v->{domain} ) ) {
        return _tag( 'email', {},
          _enc( join( '@', $v->{id}, $v->{domain} ) ) );
      }
      else {
        return '';
      }
    };
    $self->{encoder}->{author} = sub {
      my ( $n, $v ) = @_;
      my @v = ();
      push @v, _tag( 'author', {}, _enc( $v->{name} ) )
       if exists( $v->{name} );
      push @v, $self->_xml( 'email', $v->{email} )
       if exists( $v->{email} );
      return join( '', @v );
    };
  }

  # Turn version into path element
  ( my $vpath = $version ) =~ s{[.]}{/}g;

  my $ns = "http://www.topografix.com/GPX/$vpath";
  my $schema = join( ' ', $ns, "$ns/gpx.xsd", @{ $self->{schema} } );

  push @ret, qq{<gpx xmlns:xsd="http://www.w3.org/2001/XMLSchema" },
   qq{xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" },
   qq{version="$version" creator="Geo::Gpx" },
   qq{xsi:schemaLocation="$schema" }, qq{xmlns="$ns">\n};

  my @meta = ();

  for my $fld ( @META ) {
    if ( exists( $self->{$fld} ) ) {
      push @meta, $self->_xml( $fld, $self->{$fld} );
    }
  }

  my $bounds = $self->bounds( $self->iterate_points() );
  if ( %{$bounds} ) {
    push @meta, _tag( 'bounds', $bounds );
  }

  # Version 1.1 nests metadata in a metadata tag
  if ( _cmp_ver( $version, '1.1' ) >= 0 ) {
    push @ret, _tag( 'metadata', {}, "\n", @meta );
  }
  else {
    push @ret, @meta;
  }

  for my $k ( sort keys %XMLMAP ) {
    if ( exists( $self->{$k} ) ) {
      push @ret, $self->_xml( $k, $self->{$k}, $XMLMAP{$k} );
    }
  }

  push @ret, qq{</gpx>\n};

  return join( '', @ret );
}

=item TO_JSON

For compatibility with L<JSON> modules. Convert this object to a hash with keys that correspond to the above methods. Generated ala:

  my %json = map { $_ => $self->$_ }
   qw(name desc author keywords copyright
   time link waypoints tracks routes version );
  $json{bounds} = $self->bounds( $iter );

With one difference: the keys will only be set if they are defined.

=back

=cut

sub TO_JSON {
  my $self = shift;
  my %json;    #= map {$_ => $self->$_} ...
  for my $key ( @META, @ATTR, qw/ waypoints / ) {
    my $val = $self->$key;
    $json{$key} = $val if defined $val;
  }
  if ( my $bounds = $self->bounds ) {
    $json{bounds} = $self->bounds;
  }
  return \%json;
}

=over 4

=item save( filename => $fname, force => $bool, encoding => $enc )

Saves the C<Geo::Gpx> instance as a file.

All fields are optional unless the instance was created without a filename (i.e with an XML string or a filehandle) and C<set_filename()> has not been called yet. If the filename is a relative path, the file will be saved in the instance's working directory (not the caller's, C<Cwd>).

C<encoding> can be either C<utf-8> (the default) or C<latin1>.

=back

=cut

sub save {
    my ($o, %opts) = @_;
    my ($fh, $fname, $xml_string);
    if ( $opts{filename} ) { $fname = $o->set_filename( $opts{filename} ) }
    else { $fname = $o->set_filename() }
    croak "$fname already exists" if -f $fname and !$opts{force};

    $xml_string = $o->xml;
    if (defined ($opts{encoding}) and ( $opts{encoding} eq 'latin1') ) {
        open( $fh, ">:encoding(latin1)", $fname) or  die "can't open file $fname: $!";
    } else {
        open( $fh, ">:encoding(utf-8)", $fname)  or  die "can't open file $fname: $!";
    }
    print $fh $xml_string
}

=over 4

=item set_filename( $filename )

Sets/gets the filename. Returns the name of the file with the complete path.

=back

=cut

sub set_filename {
    my ($o, $fname) = (shift, shift);
    return $o->{_fileABSOLUTENAME} unless $fname;
    croak 'set_filename() takes only a single name as argument' if @_;
    my $wd;
    if ($o->_is_wd_defined) { $wd = $o->set_wd }
    # set_filename gets called before set_wd by new() so can't access work_dir until initialized

    my ($name, $path, $ext);
    ($name, $path, $ext) = fileparse( $fname, '\..*' );
    if ($wd) {
        if ( ! ($fname =~ /^\// ) ) {
            # ie if fname is not an abolsute path, adjust $path to be relative to work_dir
            ($name, $path, $ext) = fileparse( $wd . $fname, '\..*' )
        }
    }
    $o->{_fileABSOLUTEPATH} = abs_path( $path ) . '/';
    $o->{_fileABSOLUTENAME} = $o->{_fileABSOLUTEPATH} . $name . $ext;
    croak 'directory ' . $o->{_fileABSOLUTEPATH} . ' doesn\'t exist' unless -d $o->{_fileABSOLUTEPATH};
    $o->{_fileNAME} = $name;
    $o->{_filePATH} = $path;
    $o->{_fileEXT} = $ext;
    $o->{_filePARSEDNAME} = $fname;
    # _file* keys only for debugging, should not be used anywhere else
    return $o->{_fileABSOLUTENAME}
}

=over 4

=item set_wd( $folder )

Sets/gets the working directory and checks the validity of that path. Relative paths are supported for setting but only full paths are returned or internally stored.

The previous working directory is also stored in memory; can call <set_wd('-')> to switch back and forth between two directories.

Note that it does not call L<chdir>, it simply sets the path for the eventual saving of files.

=back

=cut

sub set_wd {
    my ($o, $dir) = (shift, shift);
    croak 'set_wd() takes only a single folder as argument' if @_;
    my $first_call = ! $o->_is_wd_defined;  # ie if called for 1st time -- at construction by new()

    if (! $dir) {
        return $o->{work_dir} unless $first_call;
        my $fname = $o->set_filename;
        if ($fname) {
            my ($name, $path, $ext) = fileparse( $fname );
            $o->set_wd( $path )
        } else { $o->set_wd( cwd )  }
    } else {
        $dir =~ s/^\s+|\s+$//g;                 # some clean-up
        $dir =~ s/~/$ENV{'HOME'}/ if $dir =~ /^~/;
        $dir = $o->_set_wd_old    if $dir eq '-';

        if ($dir =~ m,^[^/], ) {                # convert rel path to full
            $dir =  $first_call ? cwd . '/' . $dir : $o->{work_dir} . $dir
        }
        $dir =~ s,/*$,/,;                       # some more cleaning
        1 while ( $dir =~ s,/\./,/, );          # support '.'
        1 while ( $dir =~ s,[^/]+/\.\./,, );    # and '..'
        croak "$dir not a valid directory" unless -d $dir;

        if ($first_call) { $o->_set_wd_old( $dir ) }
        else {             $o->_set_wd_old( $o->{work_dir} ) }
        $o->{work_dir} = $dir
    }
    return $o->{work_dir}
}

# if ($o->set_filename) { $o->set_wd() }      # if we have a filename
# else {                  $o->set_wd( cwd ) } # if we don't

sub _set_wd_old {
    my ($o, $dir) = @_;
    $o->{work_dir_old} = $dir if $dir;
    return $o->{work_dir_old}
}

sub _is_wd_defined { return defined shift->{work_dir} }

#### Legacy methods from 0.10

sub gpx {
  my $self = shift;
  return $self->xml( @_ );
}

sub loc {
  my $self = shift;
  my @ret  = ();
  push @ret, qq{<?xml version="1.0" encoding="ISO-8859-1"?>\n};
  push @ret, qq{<loc version="1.0" src="Groundspeak">\n};

  if ( exists( $self->{waypoints} ) ) {
    for my $wpt ( @{ $self->{waypoints} } ) {
      push @ret, $wpt->loc();
    }
  }

  push @ret, qq{</loc>\n};

  return join( '', @ret );
}

sub gpsdrive {
  my $self = shift;
  my @ret  = ();

  if ( exists( $self->{waypoints} ) ) {
    for my $wpt ( @{ $self->{waypoints} } ) {
      push @ret, $wpt->gpsdrive();
    }
  }

  return join( '', @ret );
}

=head2 Accessors

=over 4

=item name( $str )

=item desc( $str )

=item copyright( $str )

=item keywords( $aref )

Accessors to get or set the C<name>, C<desc>, C<copyright>, or C<keywords> fields of the C<Geo::Gpx> instance.

=item author( $href )

The author information is stored in a hash that reflects the structure of a GPX 1.1 document. To set it, supply a hash reference as (C<link> and C<email> are optional):
  {
    link  => { text => 'Hexten', href => 'http://hexten.net/' },
    email => { domain => 'hexten.net', id => 'andy' },
    name  => 'Andy Armstrong'
  },

=item link( $href )

The link is stored similarly to the author information, it can be set by supplying a hash reference as:
  { link  => { text => 'Hexten', href => 'http://hexten.net/' } }

=item time( $epoch or $DateTime )

Accessor for the <time> element of a GPX. The time is converted to a Unix epoch time when a GPX document is parsed unless the C<use_datetime> option is specified in which case times will be represented as L<DateTime> objects.

When setting the time you may supply either an epoch time or a L<DateTime> object.

=item routes( $aref )

Return an array reference containing the routes of the instance. In the future, methods will be provided to set routes. In the meantime, to set the routes of the GPX instance, supply an array of hash references structured as:

  my $aref = [
    { 'name' => 'Route 1',
      'points' => [ <list_of_Geo_Gpx_Point> ]
    },
    { 'name' => 'Route 2',
      'points' => [ <list_of_Geo_Gpx_Point> ]
    },
  ];

=item tracks( $aref )

Returns an array reference containing the routes of the instance. In the future, methods will be provided to set tracks. In the meantime, to set the tracks of the GPX instance, supply an array of hash references structured as:

  my $aref = [
    { 'name' => 'Track 1',
      'segments' => [
        { 'points' => [ <list_of_Geo_Gpx_Point> ] },
        { 'points' => [ <list_of_Geo_Gpx_Point> ] },
      ]
    }
    { 'name' => 'Track 2',
      'segments' => [
        { 'points' => [ <list_of_Geo_Gpx_Point> ] },
        { 'points' => [ <list_of_Geo_Gpx_Point> ] },
      ]
    }
  ];

=item version()

Returns the schema version of a GPX document. Versions 1.0 and 1.1 are supported.

=back

=head2 Legacy methods provided for compatibility

These methods will likely removed soon as they reflect a very dated release of this module.

=over 4

=item gpx()

Synonym for C<xml()>.

=item gpsdrive()

=item loc()

Provided for compatibility with version 0.10.

=back

=head1 DEPENDENCIES

L<DateTime::Format::ISO8601>,
L<DateTime>,
L<HTML::Entities>,
L<Scalar::Util>,
L<Time::Local>,
L<XML::Descent>

=head1 SEE ALSO

L<JSON>

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to C<bug-geo-gpx@rt.cpan.org>, or through the web interface at L<http://rt.cpan.org>.

=head1 AUTHOR

Originally by Rich Bowen C<< <rbowen@rcbowen.com> >> and Andy Armstrong  C<< <andy@hexten.net> >>.

This version by Patrick Joly C<< <patjol@cpan.org> >>.

Please visit the project page at: L<https://github.com/patjoly/geo-gpx>.

=head1 VERSION

1.04

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2004-2022, Andy Armstrong C<< <andy@hexten.net> >>, Patrick Joly C<< patjol@cpan.org >>. All rights reserved.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

=cut

1;

