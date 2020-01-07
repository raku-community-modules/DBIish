
unit class DBIish::Pool;

has Int $.initial-size where ($_ >= 1);
has Int $.max-connections where ($_ >= 0);
has Int $.min-spare-connections where ($_ >= 0);

has Duration $.max-idle-duration;
has $!connection-scrub;

has $!driver;
has %!connection-args;

# Connections being started.
has atomicint $!starting-count = 0;

# Connections wanted.
has atomicint $!waiting-count = 0;

# Connections reserved for use until .dispose is called.
has atomicint $!inuse-count = 0;

# Connections being scrubbed between users.
# A large positive number may indicate poor performance with the scrub function.
has atomicint $!scrub-count = 0;

# Size of connection-queue
has atomicint $!idle-count = 0;

# Smallest number of idle connections seen in the queue. This is a best effort for queue maintenance and
# not necessarily an exact number. Performance handing out connections is more important than an exact count as a
# very busy pool is far less likely to need to terminate excess connections.
has atomicint $!min-idle-since-last-check = 0;

# Queue of connections ready for use.
has Channel $!connection-queue .= new;

has Bool $!terminate-pool = False;

# Override the connection dispose function to enable connection reuse.
role Pooled {
    has DBIish::Pool $.connection-pool is rw;
    has Bool $.pool-dispose is rw;

    method dispose() {
        self.teardown-connection();

        return $.connection-pool.reuse-connection(self);
    }

    # Warn if the connection was DESTROYed prior to pool termination. This indicates that the connection
    # went out of scope.
    submethod DESTROY() {
        $!connection-pool.dispose-connection();
    }
}

submethod BUILD(:$!driver, :$!initial-size = 1, :$!max-connections = 10, :$!min-spare-connections = 1, :$!max-idle-duration = Duration.new(60),
        Code :$!connection-scrub, *%!connection-args) { }

# Change to Lock::Async in the future once commonly available.
my Lock $new-connection-lock .= new;
submethod TWEAK() {
    start {
        # Build initial-size connections in the background. Wait a short amount of time for the
        # pool class to be fully initialized by the previous thread.
        await Promise.in(0.1);

        # Startup initial-size number of connections.
        $new-connection-lock.protect: {
            for ^$!initial-size {
                self!start-single-connection();
            }
        }

        # Terminate excess connections. This is based on the size of the pool and not use
        # of a particular connection as the pool rotates connection usage.
        until $!terminate-pool {
            await Promise.in($!max-idle-duration);

            my $kill-count = $!min-idle-since-last-check - $!min-spare-connections;
            for ^$kill-count {
                my $dbh = $!connection-queue.poll();
                if ($dbh) {
                    $!idle-count ⚛-= 1;
                    $dbh._disconnect;
                }
            }

            # Reset to the current idle connection count.
            $!min-idle-since-last-check ⚛= $!idle-count;
        }
    }
}

# Injects connections  when required. Attempts to fulfill waiting-count and ensure
# there are spares available.
method !inject-connections() {
    # Protect against a connection creation storm via multiple threads. Restrict to one new connection at a time.
    $new-connection-lock.protect: {

        # Start enough to fulfill all waiting and spare slots provided it doesn't go beyond max-connections.
        while ($!waiting-count > 0 or $!idle-count < $!min-spare-connections) and self!total-connections < $.max-connections {
            self!start-single-connection();
        }
    }
}

method !start-single-connection() {
    $!starting-count ⚛+= 1;
    my $connection = $!driver.connect(|%!connection-args);
    $!idle-count ⚛+= 1;
    $!starting-count ⚛-= 1;

    $!connection-queue.send($connection);
}

method !get-one-connection() {
    $!waiting-count ⚛+= 1;

    # Poll from the queue until a valid connection is found.
    my $dbh;
    while (not $dbh) {
        $dbh = $!connection-queue.poll();
        if ($dbh) {
            $!inuse-count ⚛+= 1;
            $!idle-count ⚛-= 1;
            $!min-idle-since-last-check ⚛= $!idle-count if ($!min-idle-since-last-check > $!idle-count);
        }
        else {
            # Start a new connection if the limit hasn't been reached. inject-connections also checks
            # this limit but preventing the start block from firing is useful on heavily loaded systems.
            if ($.max-connections > self!total-connections) {
                start {
                    self!inject-connections();
                }
            }

            # If poll wasn't successful, wait more aggressively. Either a new connection is starting or
            # the queue has reached the maximum size.
            $dbh = $!connection-queue.receive();
            $!inuse-count ⚛+= 1;
            $!idle-count ⚛-= 1;
            $!min-idle-since-last-check ⚛= $!idle-count if ($!min-idle-since-last-check > $!idle-count);
        }

        # Check the state of the connection and try the entire process again if it isn't active.
        # Dispose callback takes care to not re-add dead connections back to the pool.
        unless $dbh.ping {
            # Not taking this connection. Back out the earlier increment.
            $!inuse-count ⚛-= 1;

            $dbh.dispose;
            $dbh = Nil;
        }
    }

    $!waiting-count ⚛-= 1;

    # Override the default connection dispose function
    $dbh = $dbh but Pooled;
    # Setup a reference to this pool. It's possible a user has multiple pools active.
    $dbh.connection-pool = self;

    return $dbh;
}

multi method connect() is default {
    return self!get-one-connection();
}

multi method connect(Bool :$async! where ($_) --> Promise) {
    my $connection-promise = Promise.new();
    my $v = $connection-promise.vow();

    start {
        $v.keep(self!get-one-connection());
    }

    return $connection-promise;
}

# Due to the use of atomics rather than Lock, these stats will typically be correct but occasionally there
# is a small risk of an off-by-one error.
method stats() {
    {
        inuse => $!inuse-count,
        idle => $!idle-count,
        starting => $!starting-count,
        scrub => $!scrub-count,
        total => self!total-connections,
        waiting => $!waiting-count,
    }
}

method !total-connections( --> Int ) {
    $!idle-count + $!starting-count + $!inuse-count + $!scrub-count;
}

method dispose() {
    $!terminate-pool = True;

    # Empty the Channel.
    my $dbh;
    repeat while ($dbh) {
        $dbh = $!connection-queue.poll();
        $dbh.dispose with $dbh;
    }
}

method dispose-connection {
    # If a connection was disposed of before pool termination then it should be removed from the inuse tracker and
    # the user notified that what they've done is inefficient
    unless $!terminate-pool {
        $!inuse-count ⚛-= 1;
        warn 'Connection DESTROY without dispose() call. Connection cannot be reused in the pool';
    }
}

method reuse-connection($connection --> Bool) {
    $!scrub-count ⚛+= 1;
    $!inuse-count ⚛-= 1;

    # Connection or pool is dead. Let be disconnected.
    if (not $connection.ping or $!terminate-pool) {
        $!scrub-count ⚛-= 1;
        return True;
    }

    # Start a new thread to scrub the connection so the caller
    # can continue doing real work.
    start {
        # Scrub connection using the user-provided function or
        # using the driver default function.
        with $!connection-scrub {
            $!connection-scrub($connection);
        } else {
            $connection.scrub-state-for-reuse();
        }

        $!idle-count ⚛+= 1;
        $!scrub-count ⚛-= 1;
        $!connection-queue.send($connection);
    }

    return False;
}

