use Test::More;
use Test::Deep;
use lib lib;
use True::Truth;
use Data::Dumper;

plan qw/no_plan/;

{
    my $key = time;
    my $a = {
        domain => 'norbu09.org',
        status => 'active',
        owner  => 'lenz'
    };

    my $b = { dns => { rr => { 'norbu09.org' => '1.2.3.4', type => 'A' }, } };

    my $c = { dns => { rr => { 'norbu09.org' => '1.2.3.5', type => 'A' }, } };

    my $truth = True::Truth->new();

    my $z = $truth->add_true_truth( $key, $a );
    cmp_ok($z, '==', 0);
    my $d = $truth->get_true_truth($key);
    ok($d);
    cmp_deeply(
        $d,
        {
            'owner'  => 'lenz',
            'domain' => 'norbu09.org',
            'status' => 'active'
        }
    );
    print Dumper $d;
    my $y = $truth->add_true_truth( $key, $b );
    cmp_ok($y, '==', 1);
    $d = $truth->get_true_truth($key);
    ok($d);
    cmp_deeply(
        $d,
        {
            'owner' => 'lenz',
            'dns'   => {
                'rr' => {
                    'norbu09.org' => '1.2.3.4',
                    'type'        => 'A'
                }
            },
            'domain' => 'norbu09.org',
            'status' => 'active'
        }
    );
    print Dumper $d;
    my $x = $truth->add_pending_truth( $key, $c );
    cmp_ok($x, '==', 2);
    $d = $truth->get_true_truth($key);
    ok($d);
    cmp_deeply(
        $d,
        {
            owner  => 'lenz',
            domain => 'norbu09.org',
            dns    => {
                rr     => { 'norbu09.org' => '1.2.3.5', type => 'A' },
                _truth => 'pending'
            },
            status => 'active'
        }
    );
    print Dumper $d;
    $truth->persist_pending_truth( $key, $x );
    $d = $truth->get_true_truth($key);
    ok($d);
    cmp_deeply(
        $d,
        {
            owner  => 'lenz',
            domain => 'norbu09.org',
            dns    => {
                rr     => { 'norbu09.org' => '1.2.3.5', type => 'A' },
            },
            status => 'active'
        }
    );
    print Dumper $d;
    $truth->remove_pending_truth( $key, $x );
    $d = $truth->get_true_truth($key);
    ok($d);
    cmp_deeply(
        $d,
        {
            owner  => 'lenz',
            domain => 'norbu09.org',
            dns    => {
                rr     => { 'norbu09.org' => '1.2.3.4', type => 'A' },
            },
            status => 'active'
        }
    );
    print Dumper $d;

}
