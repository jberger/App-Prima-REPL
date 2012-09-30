package App::Prima::REPL::Plugins;

use Moo::Role;
use Module::Pluggable subname => 'list_plugins', search_path => ['App::Prima::REPL::Plugin'];

has 'plugins' => (
  is => 'ro',
  builder => sub { [ shift->list_plugins ] },
  clearer => 'clear_plugins'
);

has 'objects' => (
  is => 'ro',
  default => sub { {} },
);

sub add_plugin_namespace {
  my $self = shift;
  my ($namespace) = @_;
  $self->search_path( add => $search_path );
  $self->refresh_plugins;
}

sub refresh_plugins {
  my $self = shift;
  $self->clear_plugins;
  $self->plugins;
}

sub load_plugin {
  my $self = shift;
  my ($plugin_short) = @_;

  my $plugin = do {
    my @qualified_names = grep { /\Q$plugin_short\E/ } @{ $self->plugins };
  
    if ( @qualified_names > 1 ) {
      warn "Requested plugin not uniquely specified. Found: @qualified_names\n";
      return 0;
    }

    if ( @qualified_names == 0 ) {
      warn "Requested plugin not found\n";
      return 0;
    }

    $qualified_names[0];
  };

  unless (eval "require $plugin; 1") {
    warn "$@\n" if $@;
    warn "$plugin did not load successfully\n";
    return 0;
  }

  my $obj = eval { $plugin->new(@_) };
  if ($@) {
    warn "$@\n";
    return 0;
  }

  unless ($obj) {
    warn "$plugin object not built\n";
    return 0;
  }

  if (my $init = $obj->can('initialize')) {
    $obj->$init();
  }

  $self->objects->{ $plugin_short } = $obj;
  return $obj;
}

sub get_plugin_object {
  my $self = shift;
  my ($plugin_short) = @_;
  return $self->objects->{$plugin_short};
}

1;

