package True::Truth;

use 5.010;
use Redis;
use Any::Moose;
use MIME::Base64 qw(encode_base64 decode_base64);
use Storable qw/nfreeze thaw/;

our $VERSION = '0.5';

has 'debug' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
    lazy    => 1,
);

has 'redis_server' => (
    is      => 'rw',
    isa     => 'Str',
    default => '127.0.0.1:6379',
);

has 'redis' => (
    is      => 'rw',
    isa     => 'Redis',
    builder => '_connect_redis',
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

Version 0.5.4.3

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

    foreach my $ky (keys %$truth){
        if(ref($truth->{$ky}) eq 'HASH'){
            $truth->{$ky}->{_locked} = 1;
        } else {
            $truth->{_locked} = 1;
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
    foreach my $ky (keys %$truth){
        if(ref($truth->{$ky}) eq 'HASH'){
            delete $truth->{$ky}->{_locked};
        } else {
            delete $truth->{_locked};
        }
    }
    $self->_add($key, $truth, $index);
    return;
}

=head2 remove_pending_truth

needs docs

=cut

sub remove_pending_truth {
    my ($self, $key, $index) = @_;

    $self->_add($key, {}, $index);
    return;
}

=head2 get_true_truth

needs docs

=cut

sub get_true_truth {
    my ($self, $key) = @_;

    my $all_truth = $self->_get($key);
    my $truth = merge(@$all_truth);
    return $truth;
}

=head2 merge

needs docs

=cut

# This was stolen from Catalyst::Utils... thanks guys!
sub merge (@);
sub merge (@) {
    shift unless ref $_[0]; # Take care of the case we're called like Hash::Merge::Simple->merge(...)
    my ($left, @right) = @_;
 
    return $left unless @right;
 
    return merge($left, merge(@right)) if @right > 1;
 
    my ($right) = @right;
 
    my %merge = %$left;
 
    for my $key (keys %$right) {
 
        my ($hr, $hl) = map { ref $_->{$key} eq 'HASH' } $right, $left;
 
        if ($hr and $hl){
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
    $self->_connect_redis;
    my $idx;
    if($index){
        $idx = $index;
        $self->redis->lset($key, $index, encode_base64(nfreeze($val)));
    } else {
        $idx = $self->redis->rpush($key, encode_base64(nfreeze($val)));
        $idx -= 1;
    }
    $self->redis->expire($key, $self->expire)
        unless $self->redis->ttl($key);
    return $idx;
}

sub _get {
    my ($self, $key, $index) = @_;

    $self->_connect_redis;
    if($index){
        my $val = $self->redis->lindex($key, $index);
        return thaw(decode_base64($val))
            if $val;
    } else {
        my @data = $self->redis->lrange($key, 0, -1);
        my @res;
        foreach my $val (@data){
            push(@res, thaw(decode_base64($val)));
        }
        return \@res;
    }
    return;
}

sub _connect_redis {
    my ($self) = @_;
    return Redis->new($self->redis_server);
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

1; # This is the end of True::Truth
