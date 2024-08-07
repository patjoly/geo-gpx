# NAME

Geo::Gpx - Create and parse GPX files

# SYNOPSIS

    my ($gpx, $waypoints, $tracks);

    # From a filename, an open file, or an XML string:

    $gpx = Geo::Gpx->new( input => $fname );
    $gpx = Geo::Gpx->new( input => $fh    );
    $gpx = Geo::Gpx->new(   xml => $xml   );

    my $waypoints = $gpx->waypoints();
    my $tracks    = $gpx->tracks();

# DESCRIPTION

`Geo::Gpx` supports the parsing and generation of GPX data.

## Constructor

- new( input => ($fname | $fh) or xml => $xml \[, work\_dir => $working\_directory \] )

    Create and return a new `Geo::Gpx` instance based on a \*.gpx file (_$fname_), an open filehandle (_$fh_), or an XML string (_$xml_). GPX 1.0 and 1.1 are supported.

    The optional `work_dir` (or `wd` for short) specifies where to save any working files, such as with the save() method. It can be supplied as a relative path or as an absolute path. If `work_dir` is omitted, it is set based on the path of the _$fname_ supplied or the current working directory if the constructor is called with an XML string or a filehandle (see `set_wd()` for more info).

- clone()

    Returns a deep copy of a `Geo::Gpx` instance.

        $clone = $self->clone;

## Methods

- waypoints( $int or name => $name )

    Without arguments, returns the array reference of waypoints.

    With an argument, returns a reference to the waypoint whose `name` field is an exact match with _$name_. If an integer is specified instead of the `name` key/value pair, returns the waypoint at position _$int_ in the array reference (1-indexed with negative integers also counting from the end of the array).

    Returns `undef` if no corresponding waypoints are found such that this method can be used to check if a specific point exists (i.e. no exception is raised if _$name_ or _$int_ do not exist) .

- waypoints\_add( $point or \\%point \[, $point or \\%point, … \] )

    Add one or more waypoints. Each waypoint must be either a [Geo::Gpx::Point](https://metacpan.org/pod/Geo%3A%3AGpx%3A%3APoint) or a hash reference with fields that can be parsed by [Geo::Gpx::Point](https://metacpan.org/pod/Geo%3A%3AGpx%3A%3APoint)'s `new()` constructor. See the later for the possible fields.

        %point = ( lat => 54.786989, lon => -2.344214, ele => 512, name => 'My house' );
        $gpx->waypoints_add( \%point );

          or

        $pt = Geo::Gpx::Point->new( %point );
        $gpx->waypoints_add( $pt );

- waypoints\_search( $field => $regex )

    returns an array of waypoints whose _$field_ (e.g. `name`, `desc`, …) matches _$regex_. By default, the regex is case-sensitive; specify `qr/(?i:search_string_here)/` to ignore case.

- waypoints\_clip( $name | $regex | LIST )
- way\_clip( )

    Sends the coordinates of the waypoint(s) whose name is either `$name` or matches `$regex` to the clipboard (all points found are sent to the clipboard) and returns an array of points found. By default, the regex is case-sensitive; specify `qr/(?i:...)/` to ignore case.

    Alternatively, an array of `Geo::GXP::Points` can be provided. `way_clip()` is a short-hand for this method (convenient when used interactively in the debugger).

    This method is only supported on unix-based systems that have the `xclip` utility installed (see DEPENDENCIES).

- waypoints\_delete\_all()

    delete all waypoints. Returns true.

- waypoint\_delete( $name )

    delete the waypoint whose `name` field is an exact match for _$name_ (case sensitively). Returns true if successful, `undef` if the name cannot be found.

- waypoint\_rename( $name, $new\_name )

    rename the waypoint whose `name` field is an exact match for _$name_ (case sensitively) to _$new\_name_. Returns the point's new name if successful, `undef` otherwise.

- waypoints\_merge( $gpx, $regex )

    Merge waypoints with those contained in the [Geo::Gpx](https://metacpan.org/pod/Geo%3A%3AGpx) instance provide as argument. Waypoints are compared based on their respective `name` fields, which must exist in _$gpx_ (if names are missing in the current instance, all points will be merged).

    A _$regex_ may be provided to limit the merge to a subset of waypoints from _$gpx_.

    Returns the number of points successfully merged (i.e. the difference in `$gps->waypoints_count` before and after the merge).

- waypoint\_closest\_to( $point or $tcx\_trackpoint )
- trackpoint\_closest\_to( … )
- routepoint\_closest\_to( … )
- point\_closest\_to( … )

    From any [Geo::Gpx::Point](https://metacpan.org/pod/Geo%3A%3AGpx%3A%3APoint) or [Geo::TCX::Trackpoint](https://metacpan.org/pod/Geo%3A%3ATCX%3A%3ATrackpoint) object, return the [Geo::Gpx::Point](https://metacpan.org/pod/Geo%3A%3AGpx%3A%3APoint) that is closest to it. If called in list context, returns a two-element array consisting of that point, and the distance from the coordinate (in meters).

- waypoints\_print()

    print the list of waypoints to screen, along with their names and descriptions if defined. Returns true.

- waypoints\_count()

    returns the number of waypoints in the object.

- routes( integer or name => 'name' )

    Returns the array reference of routes when called without argument. Optionally accepts a single integer referring to the route number from routes aref (1-indexed with negative integers also counting from the end of the array) or a key value pair with the name of the route to be returned.

- routes\_add( $route or $points\_aref \[, name => $route\_name )

    Add a route to a `Geo::Gpx` object. The _$route_ is expected to be an existing route (i.e. a hash ref). Returns true. A new route can also be created based an array reference(s) of [Geo::Gpx::Point](https://metacpan.org/pod/Geo%3A%3AGpx%3A%3APoint) objects and added to the `Geo::Gpx` instance.

    `name` and all other meta fields supported by routes can be provided and will overwrite any existing fields in _$route_.

- routes\_delete\_all()

    delete all routes. Returns true.

- routes\_count()

    returns the number of routes in the object.

- tracks( integer or name => 'name' )

    Returns the array reference of tracks when called without argument. Optionally accepts a single integer referring to the track number from the tracks aref (1-indexed with negative integers also counting from the end of the array) or a key value pair with the name of the track to be returned.

- tracks\_add( $track or $points\_aref \[, $points\_aref, … \] \[, name => $track\_name \] )

    Add a track to a `Geo::Gpx` object. The _$track_ is expected to be an existing track (i.e. a hash ref). Returns true.

    If _$track_ has no `name` field and none is provided, the timestamp of the first point of the track will be used (this is experimental and may change in the future). All other fields supported by tracks can be provided and will overwrite any existing fields in _$track_.

    A new track can also be created based an array reference(s) of [Geo::Gpx::Point](https://metacpan.org/pod/Geo%3A%3AGpx%3A%3APoint) objects and added to the `Geo::Gpx` instance. If more than one array reference is supplied, the resulting track will contain as many segments as the number of aref's provided.

- tracks\_delete\_all()

    delete all tracks. Returns true.

- track\_delete( $name )

    delete the track whose `name` field is an exact match for _$name_ (case sensitively). Returns true if successful, `undef` if the name cannot be found.

- track\_rename( $name, $new\_name )

    rename the track whose `name` field is an exact match for _$name_ (case sensitively) to _$new\_name_. Returns the track's new name if successful, `undef` otherwise.

    Alternatively, an integer may be specified as the first argument, referring to the track number from tracks aref (1-indexed). This is a convenience as it is quite common for tracks to be named with the timestamp fo the first point.

- tracks\_print()

    print the list of tracks to screen, by their `name` field. Returns true.

- tracks\_count()

    returns the number of tracks in the object.

- iterate\_waypoints()
- iterate\_trackpoints()
- iterate\_routepoints()

    Get an iterator for all of the waypoints, trackpoints, or routepoints in a `Geo::Gpx` instance, as per the iterator chosen.

- iterate\_points()

    Get an iterator for all of the points in a `Geo::Gpx` instance, including waypoints, trackpoints, and routepoints.

        my $iter = $gpx->iterate_points();
        while ( my $pt = $iter->() ) {
            print "Point: ", join( ', ', $pt->{lat}, $pt->{lon} ), "\n";
        }

- bounds( $iterator )

    Compute the bounding box of all the points in a `Geo::Gpx` returning the result as a hash reference.

        my $gpx = Geo::Gpx->new( xml => $some_xml );
        my $bounds = $gpx->bounds();

    returns a structure like this:

        $bounds = {
          minlat => 57.120939,
          minlon => -2.9839832,
          maxlat => 57.781729,
          maxlon => -1.230902
        };

    `$iterator` defaults to `$self->iterate_points` if not specified.

- xml( key/values )

    Generate and return an XML string representation of the instance.

    _key/values_ are (all optional):

        `version`:        specifies the GPX XML version scheme to use (defaults to 1.0).
        `unsafe_chars`:   the set of characters to be considered unsafe for the XML mark-up and encoded as an entity.

    If `version` is omitted, it defaults to the value of the `version` attribute. Parsing a GPX document sets the version. If the `version` attribute is unset defaults to 1.0.

    `unsafe_chars` can be provided to specify which characters to consider unsafe in generating the XML mark-up. This field is then passed through to [HTML::Entities](https://metacpan.org/pod/HTML%3A%3AEntities) function calls whose documentation describes that this field is "specified using the regular expression character class syntax (what you find within brackets in regular expressions)".

    As of version _1.11_ of `Geo::Gpx`, the default set of characters are the `'<'`, `'&'`, `'>'`, `'"'` characters. To revert to the pre-version _1.11_ default, which is equivalent to that in <`HTML::Entities`, explicitely specify `unsafe_chars => undef`. This will encode as the latter module describes the "control chars, high-bit chars, and the `'<'`, `'&'`, `'>'`, `"'"`, `'"'` characters".

- TO\_JSON

    For compatibility with [JSON](https://metacpan.org/pod/JSON) modules. Convert this object to a hash with keys that correspond to the above methods. Generated ala:

        my %json = map { $_ => $self->$_ }
            qw( name desc author keywords copyright
                time link waypoints tracks routes version );
        $json{bounds} = $self->bounds( $iter );

    With one difference: the keys will only be set if they are defined.

- save( filename => $fname, key/values )

    Saves the `Geo::Gpx` instance as a file.

    The filename field is optional unless the instance was created without a filename (i.e with an XML string or a filehandle) and `set_filename()` has not been called yet. If the filename is a relative path, the file will be saved in the instance's working directory (not the caller's, `Cwd`).

    _key/values_ are (all optional):

        `force`:      overwrites existing files if true, otherwise it won't.
        `extensions`: save `<extensions>…</extension>` tags if true (defaults to false).
        `meta_time`:  save the `<time>…</time>` tag in the file's meta information tags if true (defaults to false). Some applications like MapSource return an error if this tags is present. (All other time tags elsewhere are kept.)
        `unsafe_chars`:   see the documentation for `xml()` above.

- set\_filename( $filename )

    Sets/gets the filename. Returns the name of the file with the complete path.

- set\_wd( $folder )

    Sets/gets the working directory for any eventual saving of the \*.gpx file and checks the validity of that path. It can be set as a relative path (i.e. relative to the actual [Cwd](https://metacpan.org/pod/Cwd)) or as an absolute path, but is always returned as a full path.

    This working directory is always defined. The previous one is also stored in memory, such that `set_wd('-')` switches back and forth between two directories. The module never actually `chdir`'s, it just keeps track of where the user wishes to save files.

## Accessors

- name( $str )
- desc( $str )
- copyright( $str )
- keywords( $aref )

    Accessors to get or set the `name`, `desc`, `copyright`, or `keywords` fields of the `Geo::Gpx` instance.

- author( $href )

    The author information is stored in a hash that reflects the structure of a GPX 1.1 document. To set it, supply a hash reference as (`link` and `email` are optional):
      {
        link  => { text => 'Hexten', href => 'http://hexten.net/' },
        email => { domain => 'hexten.net', id => 'andy' },
        name  => 'Andy Armstrong'
      },

- link( $href )

    The link is stored similarly to the author information, it can be set by supplying a hash reference as:
      { link  => { text => 'Hexten', href => 'http://hexten.net/' } }

- time( $epoch )

    Accessor for the &lt;time> element of a GPX. The time is converted to a Unix epoch time when a GPX document is parsed, therefore only epoch time is supported for setting.

- version()

    Returns the schema version of a GPX document. Versions 1.0 and 1.1 are supported.

# DEPENDENCIES

[DateTime](https://metacpan.org/pod/DateTime),
[DateTime::Format::ISO8601](https://metacpan.org/pod/DateTime%3A%3AFormat%3A%3AISO8601),
[Geo::Coordinates::Transform](https://metacpan.org/pod/Geo%3A%3ACoordinates%3A%3ATransform),
[HTML::Entities](https://metacpan.org/pod/HTML%3A%3AEntities),
[Math::Trig](https://metacpan.org/pod/Math%3A%3ATrig),
[Scalar::Util](https://metacpan.org/pod/Scalar%3A%3AUtil),
[XML::Descent](https://metacpan.org/pod/XML%3A%3ADescent)

The `waypoints_clip()` method is only supported on unix-based systems that have the `xclip` utility installed.

# SEE ALSO

[JSON](https://metacpan.org/pod/JSON)

# BUGS AND LIMITATIONS

Prior to version 1.11, `xml()` and `save()` encoded "unsafe characters" as per the default in [HTML::Entities](https://metacpan.org/pod/HTML%3A%3AEntities) which resulted in erroneous codes for some multi-byte unicode characters. The current default is to only encode a short list of characters -- see `xml()` above. This change is motivated by the now prevalent use of unicode as the default encoding in many applications that read XML markup and \*.gpx files.

Please report any bugs or feature requests on the github project page. Alternatively, you may submit them to `bug-geo-gpx@rt.cpan.org` or through the web interface at [http://rt.cpan.org](http://rt.cpan.org).

# AUTHOR

Originally by Rich Bowen `<rbowen@rcbowen.com>` and Andy Armstrong  `<andy@hexten.net>`.

This version by Patrick Joly `<patjol@cpan.org>`.

Please visit the project page at: [https://github.com/patjoly/geo-gpx](https://github.com/patjoly/geo-gpx).

# VERSION

1.11

# LICENSE AND COPYRIGHT

Copyright (c) 2004-2022, Andy Armstrong `<andy@hexten.net>`, Patrick Joly `patjol@cpan.org`. All rights reserved.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic).

# DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENSE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
