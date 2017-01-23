=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Genome;

use strict;

use HTML::Entities qw(encode_entities);

use parent qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self          = shift;
  my $hub           = $self->hub;
  my $id            = $hub->param('id');
  my $db            = $hub->param('db') || 'core';
  my $object_type   = $hub->param('ftype');
  my $db_adaptor    = $hub->database(lc($db));
  my $adaptor_name  = "get_${object_type}Adaptor";
  my $feat_adap     = $db_adaptor->$adaptor_name;

  my $features      = $feat_adap->can('fetch_all_by_hit_name')
    ? $feat_adap->fetch_all_by_hit_name($id)
      : $feat_adap->can('fetch_all_by_probeset_name')
        ? $feat_adap->fetch_all_by_probeset_name($id)
          : []
            ;

  my $external_db_id  = $features->[0] && $features->[0]->can('external_db_id') ? $features->[0]->external_db_id : '';
                                        my $extdbs          = $external_db_id ? $hub->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'external_db'}{'entries'} : {};
  my $hit_db_name     = $extdbs->{$external_db_id}->{'db_name'} || 'External Feature';

  my $logic_name      = $features->[0] ? $features->[0]->analysis->logic_name : undef;

  $hit_db_name        = 'TRACE' if $logic_name =~ /sheep_bac_ends|BACends/; # hack to link sheep bac ends to trace archive;

  $self->caption("$id ($hit_db_name)");

  my ($desc)          = $hit_db_name =~ /CCDS/ ? () : split("\n", $hub->get_ext_seq($hit_db_name, {'id' => $id, 'translation' => 1})->{'sequence'} || ''); # don't show EMBL desc for CCDS

  $self->add_entry({ label => $desc }) if $desc && $desc =~ s/^>//;

  #Uniprot can't deal with versions in accessions, but the Location/Genome link needs them
  my $orig_id = $id;
  if ($hit_db_name =~ /^Uniprot/){
    $id =~ s/(\w*)\.\d+/$1/;
  }

  $self->add_entry({
    'label' => $hit_db_name eq 'TRACE' ? 'View Trace archive' : $id,
    'link'  => encode_entities($hub->get_ExtURL($hit_db_name, $id)),
    'external' => 1,
  });

  if ($logic_name and my $ext_url = $hub->get_ExtURL($logic_name, $id)) {
    $self->add_entry({
      'label' => "View in external database",
      'link'  => encode_entities($ext_url),
      'external' => 1,
    });
  }

  $self->add_entry({
    'label'   => 'View all hits',
    'link'    => $hub->url({
      'type'    => 'Location',
      'action'  => 'Genome',
      'ftype'   => $object_type,
      'id'      => $orig_id,
      'db'      => $db,
      '__clear' => 1
    })
  });

## VB - fix for ENSEMBL-4684 - should be safe to drop this in VB-2017-04
##      assuming this PR is merged https://github.com/Ensembl/ensembl-webcode/pull/527
  my @attrs = @{ $features->[0]->get_all_Attributes };

  foreach my $attr ( sort {$a->name cmp $b->name} @attrs ) {
    $self->add_entry({
      'type'  => $attr->name,
      'label' => $attr->value
    });
  }
##  
}

1;
