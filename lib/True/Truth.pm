package True::Truth;

use 5.010;
use Cache::KyotoTycoon;
use Any::Moose;
use MIME::Base64 qw(encode_base64 decode_base64);
use Storable qw/nfreeze thaw/;
use Data::Dump qw/dump/;
use Time::HiRes qw/gettimeofday/;

# ABSTRACT: merge multiple versions of truth into one
#
# VERSION

has 'debug' => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub { 0 },
    lazy    => 1,
);

has 'kt_server' => (
    is      => 'rw',
    isa     => 'Str',
    default => '127.0.0.1',
);

has 'kt_port' => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { 1978 },
);

has 'kt_db' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 0 },
);

has 'kt_timeout' => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { 5 },
);

has 'kt' => (
    is      => 'rw',
    isa     => 'Cache::KyotoTycoon',
    builder => '_connect_kt',
    lazy    => 1,
);

has 'expire' => (
    is      => 'rw',
    isa     => 'Int',
    default => '3600',
);

=head1 NAME

True::Truth - The one True::Truth!

=head1 VERSION

# VERSION

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use True::Truth;

    my $foo = True::Truth->new();
    ...


=head1 FUNCTIONS

=head2 add_true_truth

needs docs

=cut

sub add_true_truth {
    my ($self, $key, $truth) = @_;

    return int $self->_add($key, $truth);
}

=head2 add_pending_truth

needs docs

=cut

sub add_pending_truth {
    my ($self, $key, $truth) = @_;

    return unless ref $truth eq 'HASH';

    foreach my $ky (keys %$truth) {
        if (ref($truth->{$ky}) eq 'HASH') {
            $truth->{$ky}->{_maybe} = 1;
        }
        else {
            $truth->{_maybe} = 1;
        }
    }
    return int $self->_add($key, $truth);
}

=head2 persist_pending_truth

needs docs

=cut

sub persist_pending_truth {
    my ($self, $key, $index) = @_;

    my $truth = $self->_get($key, $index);

    return unless ref $truth eq 'HASH';

    foreach my $k (keys %$truth) {
        if (ref($truth->{$k}) eq 'HASH') {
            delete $truth->{$k}->{_maybe};
            $truth->{$k}->{_true} = 1;
        }
        else {
            delete $truth->{_maybe};
            $truth->{_true} = 1;
        }
    }
    $self->_add($key, $truth, $index);
    return;
}

# TODO add a mark_truth_failed or similar function that makes the truth
# aware of failed facets
=head2 remove_pending_truth

needs docs

=cut

sub remove_pending_truth {
    my ($self, $key, $index) = @_;

    $self->_del($key, $index);
    return;
}

=head2 get_true_truth

needs docs

=cut

sub get_true_truth {
    my ($self, $key) = @_;

    my $all_truth = $self->_get($key);
    # TODO needs to merge only hashes that are true already and push all
    # pending thruth facets to _pending
    my $pending_truth;
    my $pending_counter;
    my $counter = 0;
    foreach my $truth (@{$all_truth}){
        if(_is($truth, 'maybe')){
            push(@{$pending_truth->{'_pending'}}, $truth);
            $pending_counter ++;
            delete $all_truth->[$counter];
        }
        $counter ++;
    }
    unshift(@{$all_truth}, $pending_truth)
        if $pending_truth;
    my $truth     = merge(@$all_truth);
    $truth->{_pending_count} = $pending_counter if $pending_counter;
    return $self->_clean_truth($truth);
}


=head2 get_future_truth

Get the perfect truth we what to have

This function returns true hash

=cut

sub get_future_truth {
    my ($self, $key) = @_;

    my $all_truth = $self->_get($key);
    my $truth     = merge(@$all_truth);
    return $self->_clean_truth($truth);
}


=head2 rebase_truth

Take a new 'base truth' and calculate which of the facets are already applied to this truth and which are still pending

This function returns a truth hash

=cut

sub rebase_truth {
    my ($self, $truth) = @_;

    return;
}

=head2 merge

needs docs

=cut

# This was stolen from Catalyst::Utils... thanks guys!
sub merge (@);

sub merge (@) {
    shift
        unless ref $_[0]
        ; # Take care of the case we're called like Hash::Merge::Simple->merge(...)
    my ($left, @right) = @_;

    #_clean_hash($left);
    return $left unless @right;

    return merge($left, merge(@right)) if @right > 1;

    my ($right) = @right;

    my %merge = %$left;

    for my $key (keys %$right) {

        #_clean_hash($key);
        my ($hr, $hl) = map { ref $_->{$key} eq 'HASH' } $right, $left;

        if ($hr and $hl) {
            $merge{$key} = merge($left->{$key}, $right->{$key});
        }
        else {
            $merge{$key} = $right->{$key};
        }
    }

    return \%merge;
}

#### internal stuff ####

sub _add {
    my ($self, $key, $val, $index) = @_;

    my $idx;
    if ($index) {
        $idx = $index;
    }
    else {
        $idx = gettimeofday;
    }
    $self->kt->set("$key.$idx", encode_base64(nfreeze($val)), $self->expire);
    return $idx;
}

sub _get {
    my ($self, $key, $index) = @_;

    if ($index) {
        my $val = $self->kt->get("$key.$index");
        return thaw(decode_base64($val))
            if $val;
    }
    else {
        my $data = $self->kt->match_prefix($key);
        my @res;
        foreach my $val (sort keys %{$data}) {
            push(@res, thaw(decode_base64($self->kt->get($val))));
        }
        return \@res;
    }
    return;
}

sub _del {
    my ($self, $key, $index) = @_;

    if ($index) {
        $self->kt->remove("$key.$index");
    }
    else {
        my $data = $self->kt->match_prefix($key);
        foreach my $val (sort keys %{$data}) {
            $self->kt->remove($val);
        }
    }
    return;
}

sub _connect_kt {
    my ($self) = @_;
    return Cache::KyotoTycoon->new(
        host    => $self->kt_server,
        port    => $self->kt_port,
        timeout => $self->kt_timeout,
        db      => $self->kt_db,
    );
}

sub _clean_truth {
    my ($self, $hash) = @_;

    # TODO refactor to use new _is function
    return $hash unless ref($hash) eq 'HASH';
    foreach my $k (keys %{$hash}){
        if (ref($hash->{$k}) eq 'HASH') {
            foreach my $j (keys %{$hash->{$k}}){
                if(exists $hash->{$k}->{_maybe}){
                    $hash->{_pending_count} ++;
                    delete $hash->{$k}->{_maybe};
                } elsif (exists $hash->{$k}->{_true}){
                    delete $hash->{$k}->{_true};
                }
            }
        }
        else {
            if(exists $hash->{_maybe}){
                $hash->{_pending_count} ++;
                delete $hash->{_maybe};
            } elsif (exists $hash->{_true}){
                delete $hash->{_true};
            }
        }
    }
    return $hash;
}

sub _is {
    my ($truth, $mode) = @_;

    return unless $mode;


    foreach my $ky (keys %$truth) {
        if (ref($truth->{$ky}) eq 'HASH') {
            return 1 if exists $truth->{$ky}->{'_'.$mode};
        }
        else {
            return 1 if exists $truth->{'_'.$mode};
        }
    }
    return;
}

=head1 AUTHOR

Lenz Gschwendtner, C<< <norbu09 at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-true-truth at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=True-Truth>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc True::Truth


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=True-Truth>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/True-Truth>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/True-Truth>

=item * Search CPAN

L<http://search.cpan.org/dist/True-Truth/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Lenz Gschwendtner.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # This is the end of True::Truth
