package Math::Grid::Coordinates;

use Moose;
use Moose::Util::TypeConstraints;

has [ qw/grid_width grid_height page_width page_height/ ] => ( is => 'rw', isa => 'Int' );

has [ qw/page_width page_height/ ] => ( is => 'rw', isa => 'Num' );

# item size
has [ qw/item_width item_height/ ] => ( is => 'rw', isa => 'Num' );

# gutter border
has [ qw/gutter gutter_h gutter_v border border_l border_r border_t border_b/ ] => ( is => 'rw', isa => 'Num' );

subtype 'Seq', as 'Str', where { /^[h,v]$/i };
has arrange => ( is => 'rw', isa => 'Str', default => sub { 'h' } );


around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $opts;

    if ( !ref $_[0] ) {
	my %h;
	@h{qw/grid_width grid_height item_width item_height gutter border/} = grep { /[^a-z]/i } @_;

	($h{arrange}) = (grep { /^[h,v]i/ } @_) || ('h');
	$h{gutter} ||= 0;
	$h{border} ||= 0;
	# return $class->$orig( \%h );
	$opts = \%h;
    } else {
	$opts = shift;
    }
    $opts->{gutter_h} //= $opts->{gutter} // 0;
    $opts->{gutter_v} //= $opts->{gutter} // $opts->{gutter_v} // 0;

    $opts->{border_t} //= $opts->{border} // $opts->{gutter_v} // 0;
    $opts->{border_b} //= $opts->{border_t} // $opts->{border} // $opts->{gutter_v} // 0;

    $opts->{border_l} //= $opts->{border} // $opts->{gutter_h} // 0;
    $opts->{border_r} //= $opts->{border_l};

    my $obj = $class->$orig($opts);
    return $obj;
};

sub total_height {
    my $self = shift;
    return $self->border_t + $self->item_height * $self->grid_height + $self->gutter_v * ($self->grid_height - 1) + $self->border_b;
};

sub total_width {
    my $self = shift;
    return $self->border_l + $self->item_width * $self->grid_width + $self->gutter_h * ($self->grid_width - 1) + $self->border_r
};

sub bbox {
    my $self = shift;
    my ($w, $h) = ($self->total_width, $self->total_height);
    return wantarray ? ($w, $h) : [ $w, $h ];
}

sub sequence {
    my $self = shift;
    my ($gw, $gh) = map { $self->$_ } qw/grid_width grid_height/; 
    my @sequence;

    if (lc($self->arrange) eq 'v') {
	for my $x (0..$gw-1) { for my $y (0..$gh-1) { push @sequence, [$x, $y] } }
    } else {
	for my $y (0..$gh-1) { for my $x (0..$gw-1) { push @sequence, [$x, $y] } }
    }
    return @sequence;
}

sub position {
    my $self = shift;

    my ($x, $y) = @_;
    my ($iw, $ih, $gt_h, $gt_v, $bl, $bt) = map { $self->$_ } qw/item_width item_height gutter_h gutter_v border_l border_t/; 

    return (
	    $bl + $iw * $x + $gt_h * $x,
	    $bt + $ih * $y + $gt_v * $y
	   )
}

sub positions {
    my $self = shift;

    # first assign positions in terms of page coordinates
    my @grid = $self->sequence;

    # then calculate and assign the actual position
    my @pos = map {
	[ $self->position(@$_) ]
    } @grid;

    return @pos;
}

sub block {
    my $self = shift;
    my ($x, $y, $w, $h) = @_;

    my ($iw, $ih, $gt_h, $gt_v, $bl, $bt) = map { $self->$_ } qw/item_width item_height gutter_h gutter_v border_l border_t/; 

    my ($x_pos, $y_pos) = (
			   $bl + $iw * $x + $gt_h * $x,
			   $bt + $ih * $y + $gt_v * $y,
			  );

    my ($width, $height) = (
			   $iw * $w + $gt_h * ($w - 1),
			   $ih * $h + $gt_v * ($h - 1),
			   );

    return ($x_pos, $y_pos, $width, $height)
}

sub guides {
    my $self = shift;
    my @guides;
    my ($h, $w, $ih, $iw) = map { $self->$_ } qw/page_height page_width item_height item_width/;

    for (0..$self->grid_width-1) {
	my $p = [ $self->position($_, 0) ]->[0];
	push @guides, [ [ $p, 0 ], [ $p, $h ] ];
	push @guides, [ [ $p + $iw, 0 ], [ $p + $iw, $h ] ];
    }
    for (0..$self->grid_height-1) {
	my $p = [ $self->position(0, $_) ]->[1];
	push @guides, [ [ 0, $p ], [ $w, $p ] ];
	push @guides, [ [ 0, $p + $ih ], [ $w, $p + $ih ] ];
    }
    return @guides;
}

sub marks {
    my $self = shift;
    my $l = shift || 12;
    my (@h_marks, @v_marks);
    my ($h, $w, $ih, $iw) = map { $self->$_ } qw/page_height page_width item_height item_width/;

    for (0..$self->grid_width-1) {
	my $p = [ $self->position($_, 0) ]->[0];
	push @v_marks, [ [ $p, 0 ], [ $p, -$l ] ];
	push @v_marks, [ [ $p + $iw, 0 ], [ $p + $iw, -$l ] ];
	push @v_marks, [ [ $p, $h ], [ $p, $h + $l ] ];
	push @v_marks, [ [ $p + $iw, $h ], [ $p + $iw, $h + $l ] ];
    }
    for (0..$self->grid_height-1) {
	my $p = [ $self->position(0, $_) ]->[1];
	push @h_marks, [ [ -$l, $p ], [ 0, $p ] ];
	push @h_marks, [ [ -$l, $p + $ih ], [ 0, $p + $ih ] ];
	push @h_marks, [ [ $w, $p ], [ $w + $l, $p ] ];
	push @h_marks, [ [ $w, $p + $ih ], [ $w + $l, $p + $ih ] ];
    }
    return (@v_marks, @h_marks);
}


sub calculate {
    my $self = shift;

    my $avail_v = $self->page_height - ($self->border_t + $self->gutter_v * ($self->grid_height - 1) + $self->border_b);
    my $avail_h = $self->page_width  - ($self->border_l + $self->gutter_h * ($self->grid_width  - 1) + $self->border_r);

    # print $avail_h, $avail_v;

    $self->item_width($avail_h / $self->grid_width);
    $self->item_height($avail_v / $self->grid_height);

    return $self;
}


sub numbers {
    my $self = shift;
    return (1..($self->grid_width * $self->grid_height))
}

__PACKAGE__->meta->make_immutable;

1;

#################### pod generated by Pod::Autopod - keep this line to make pod updates possible ####################

=head1 NAME

Grid - create geometric grids

=head1 SYNOPSYS

 use Grid;

 my $grid = Grid->new($grid_width, $grid_height, $item_width, $item_height, $gutter, $border, $arrangement);

=head1 DESCRIPTION

Grid creates an array of x-y positions for items of a given height and width arranged in a grid. This is used to create grid layouts on a page, or repeate items on a number of pages of the same size.

=head1 REQUIRES

L<Moose> 

L<Moose::Util::TypeConstraints> 

=head1 METHODS

=head2 bbox

 $grid->bbox();

Returns the total bounding box of the grid 

=head2 numbers

 $grid->numbers();

Returns the sequence item numbers, with the top left item as item 1.

 +---------+---------+---------+---------+
 |         |         |         |         |
 |    1    |    2    |    3    |    4    |
 |         |         |         |         |
 +---------+---------+---------+---------+
 |         |         |         |         |
 |    5    |    6    |    7    |    8    |
 |         |         |         |         |
 +---------+---------+---------+---------+
 |         |         |         |         |
 |    9    |   10    |   11    |   12    |
 |         |         |         |         |
 +---------+---------+---------+---------+

=head2 sequence

 $grid->sequence();

Returns the sequence of x-y grid item coordinates, with the top left item as item C<[0, 0]>, the next one (assuming a horizontal arrangement) being C<[1, 0]> etc. 

 +---------+---------+---------+---------+
 |         |         |         |         |
 | [0, 0]  | [0, 1]  | [0, 2]  | [0, 3]  |
 |         |         |         |         |
 +---------+---------+---------+---------+
 |         |         |         |         |
 | [1, 0]  | [1, 1]  | [1, 2]  | [1, 3]  |
 |         |         |         |         |
 +---------+---------+---------+---------+
 |         |         |         |         |
 | [2, 0]  | [2, 1]  | [2, 2]  | [2, 3]  |
 |         |         |         |         |
 +---------+---------+---------+---------+

=head2 position

 $grid->position(0, 0);

Returns the position of item as an array of x and y coordinates.

=head2 block

 $grid->block($x, $y, $width, $height);

Returns the position and size of item as an array of x and y coordinates, and width and height.

=head2 positions

 $grid->positions();

Returns the sequence of x-y grid coordinates.

=head2 total_height

 $grid->total_height();

The total height of the grid

=head2 total_width

 $grid->total_width();

The total width of the grid

=head2 calculate

 $grid->calculate();

Calculates item width and height based on page size, borders, gutters and item count

=head2 guides

 $grid->guides();

Returns start and end coordinates of layout guides

=head2 marks

 $grid->marks();

Returns start and end coordinates of layout marks (short lines outside page)

=head1 To do

=over 4

=item *

Allow for bottom or top start of grid

=back

=cut
