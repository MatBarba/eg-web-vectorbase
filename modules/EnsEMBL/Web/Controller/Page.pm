=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Controller::Page;

use strict;
use warnings;

use URI::Escape qw(uri_unescape);
use EnsEMBL::Web::Exceptions;
use JSON;

sub init {
  my $self  = shift;
  my $hub   = $self->hub;

  # Clear already existing cache if required
  $self->clear_cached_content;

  # Try to retrieve content from cache
  my $cached = $self->get_cached_content;

## VB
  if (!$cached) {
    my $redirection_required;
    try {
      $self->builder->create_objects;
    } catch {
      if ($_->type eq 'RedirectionRequired') {
        $redirection_required = $_;
      } else {
        throw $_;
      }
    };
    $self->configure;
    $self->update_configuration_for_request;
    
    if ($redirection_required) { # trigger redirection after applying configuration
      $hub->store_records_if_needed;
      throw $redirection_required;
    }
  }
##

  $self->update_user_history if $hub->user;

  return if $cached;

  $self->page->initialize; # Adds the components to be rendered to the page module
  $self->render_page;
}

sub update_configuration_for_request {
  ## Checks for shared data and updates config settings from the URL and POST parameters
  ## TODO - handle share userdata via url - did not work in 84 either
  my $self        = shift;
  my $r           = $self->r;
  my $input       = $self->input;
  my $hub         = $self->hub;
  my $core_params = $hub->core_params;
  my @components  = @{$self->configuration->get_configurable_components};

  my $do_redirect = 0;

  # Go through each view config and get a list of required params
  my @view_config = map $hub->get_viewconfig({'type' => $components[$_][1], 'component' => $components[$_][0]}), 0..$#components;
  my %url_params  = map { $_ => 1 } map $_->config_url_params, @view_config;
  my %inp_params;

  # Get all the required params from the url and delete the one in the url
  for (keys %url_params) {
    my @vals = $input->param($_);
    if (@vals) {
      $input->delete($_);
      $url_params{$_} = scalar @vals > 1 ? \@vals : $vals[0];
    } else {
      delete $url_params{$_}; # delete the params not present in the url
    }
  }

  # Get all the non-core GET/POST params to pass them to the update_for_input method
  for ($input->param) {
    next if $core_params->{$_};
    my @vals = $input->param($_);
    $inp_params{$_} = scalar @vals > 1 ? \@vals : $vals[0];
  }

  # now update all the view configs accordingly
  for (@view_config) {
    if (keys %inp_params) {
## VB      
      $inp_params{$_} = from_json($inp_params{$_} || '{}') for grep $inp_params{$_}, qw(image_config view_config);
##    
      $_->update_from_input({ %inp_params }); # avoid passing reference to the original hash to prevent manipulation
    }
    if (keys %url_params) {
      $_->update_from_url({ %url_params });
      $do_redirect++;
    }
  }

  if ($do_redirect) {
    $input->param('time', time); # Add time to cache-bust the browser
    $hub->redirect(join('?', $r->uri, uri_unescape($input->query_string)));
  }
}

1;