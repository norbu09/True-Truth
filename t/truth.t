use Test::More;
use Test::Deep;
use lib 'lib';
use Data::Dumper;
use Time::HiRes qw/gettimeofday/;

plan qw/no_plan/;

{

    BEGIN { use_ok('True::Truth'); }
    my $truth = True::Truth->new();
    ok($truth);

    SKIP: {
        eval { $truth->_connect_kt() };

        skip "KyotoTycoon not running", 13 if $@;

        my $key = time;
        print "Key: $key\n";

        my $a =
            { domain => 'norbu09.org', status => 'active', owner => 'lenz' };
        my $b =
            { dns => { rr => { 'norbu09.org' => '1.2.3.4', type => 'A' }, } };
        my $c =
            { dns => { rr => { 'norbu09.org' => '1.2.3.5', type => 'A' }, } };

        my $z = $truth->add_true_truth($key, $a);
        cmp_ok($z, '<=', gettimeofday, "check index");
        my $d = $truth->get_true_truth($key);
        ok($d);
        cmp_deeply(
            $d, {
                'owner'  => 'lenz',
                'domain' => 'norbu09.org',
                'status' => 'active'
            },
            "check hash structure"
        );
        print Dumper $d;

        my $y = $truth->add_true_truth($key, $b);
        cmp_ok($y, '<=', gettimeofday, "check index");
        $d = $truth->get_true_truth($key);
        ok($d);
        cmp_deeply(
            $d, {
                'owner' => 'lenz',
                'dns'   => {
                    'rr' => {
                        'norbu09.org' => '1.2.3.4',
                        'type'        => 'A'
                    }
                },
                'domain' => 'norbu09.org',
                'status' => 'active',
            },
            "check hash structure"
        );
        print Dumper $d;

        my $x = $truth->add_pending_truth($key, $c);
        cmp_ok($x, '<=', gettimeofday, "check index");
        $d = $truth->get_true_truth($key);
        ok($d);
        cmp_deeply(
            $d, {
                owner  => 'lenz',
                domain => 'norbu09.org',
                dns    => {
                    rr => { 'norbu09.org' => '1.2.3.4', type => 'A' },
                },
                status     => 'active',
                _pending_count => 1,
                _pending => [ {
                        dns => {
                            rr => { 'norbu09.org' => '1.2.3.5', type => 'A' },
                        }
                    },
                ],
            },
            "check hash structure"
        );
        print Dumper $d;

        $f = $truth->get_future_truth($key);
        ok($f);
        cmp_deeply(
            $f, {
                owner  => 'lenz',
                domain => 'norbu09.org',
                dns    => {
                    rr => { 'norbu09.org' => '1.2.3.5', type => 'A' },
                },
                status     => 'active',
                _pending_count => 1,
            },
            "check hash structure"
        );
        print Dumper $f;

        $truth->persist_pending_truth($key, $x);
        $d = $truth->get_true_truth($key);
        ok($d);
        cmp_deeply(
            $d, {
                owner  => 'lenz',
                domain => 'norbu09.org',
                dns => { rr => { 'norbu09.org' => '1.2.3.5', type => 'A' }, },
                status => 'active'
            },
            "check hash structure"
        );
        print Dumper $d;

        $truth->remove_pending_truth($key, $x);
        $d = $truth->get_true_truth($key);
        ok($d);
        cmp_deeply(
            $d, {
                owner  => 'lenz',
                domain => 'norbu09.org',
                dns => { rr => { 'norbu09.org' => '1.2.3.4', type => 'A' }, },
                status => 'active'
            },
            "check hash structure"
        );
        print Dumper $d;
    }

}
