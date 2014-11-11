package AppCore::Web::Controller;
{
	use strict;
	use AppCore::Web::Common;
	
	use base 'AppCore::SimpleObject';
	
	use AppCore::Web::Router;
	
	# For output_json()
	use JSON qw/encode_json/;
		
	our %SelfCache = ();
	
	sub new 
	{
		my $class = shift;
		my %args = @_;
		
		return bless { %args }, $class;
	}
	
	sub stash
	{
		my $self = shift;
		my %args = @_;
		
		if(!ref $self)
		{
			$SelfCache{$self} ||= {};
			$self = $SelfCache{$self};
		}
		
		$self->{_stash} ||= AppCore::SimpleObject->new();
		if(scalar(keys %args) > 0)
		{
			$self->{_stash}->_accessor($_, $args{$_})
				foreach keys %args;
		}
		
		return $self->{_stash};
	}
	
	sub set_stash
	{
		my ($self, $stash, $merge_flag) = @_;
		
		if(!ref $self)
		{
			$SelfCache{$self} ||= {};
			$self = $SelfCache{$self};
		}
		
		if($merge_flag)
		{
			my $cur_stash = $self->stash;
		
			$stash->{$_} = $cur_stash->{$_}
				foreach keys %{$cur_stash || {}};
		}
		
		$self->{_stash} = $stash;
	}
	
	sub router
	{
		my $class = shift;
		my $self = $class;
		
		if(!ref $self)
		{
			$SelfCache{$class} ||= {};
			$self = $SelfCache{$class};
		}
		
		# Pass '$class' to the Router instead of '$self' because $self could be fake.
		# Router calls '->can' on $class, which works if $class is a string ('Foo::Bar')
		# or a blessed reference - but fails if its just a regular unblessed HASH,
		# which $self could be due to the previous block.
		$self->{_router} ||= AppCore::Web::Router->new($class);
		
		return $self->{_router};
	}
	
	sub setup_routes
	{
		# NOTE: Reimplement in subclass
		
		my $class = shift;
		print_stack_trace();
		warn __PACKAGE__.": You need to reimplement 'setup_routes()' in the '$class' class";
	}
	
	sub output
	{
		my $class = shift;
		
		return if ! $class->stash->{r};
		
		$class->stash->{r}->output(@_);
	}
	
	sub output_data
	{
		my $class = shift;
		
		return if ! $class->stash->{r};
		
		$class->stash->{r}->output_data(@_);
	}
	
	# I found myself repeatedly calling output_data 
	# just to output json, so I added this as a shortcut
	sub output_json
	{
		my $class = shift;
		my $val   = shift;
		my $json  = ref $val ? encode_json($val) : $val;
		$class->output_data('application/json', $json);
	}
	
	sub request
	{
		my $class = shift;
		
		return $class->stash->{req};
	}
	
	sub redirect
	{
		my $class = shift;
		my $url   = shift;
		die "No 'r' object in class->stash'" if !$class->stash->{r};
		#die Dumper $url;
		return $class->stash->{r}->redirect($url);
	}
	
	sub url_up
	{
		my $class = shift;
		my $count = shift;
		
		die "No request in class stash (stash->{req} undef)"
			if ! $class->stash->{req};
			
		my $url = $class->stash->{req}->prev_page_path($count);
		
		return $url;
	}
	
	sub url
	{
		my $class = shift;
		my $count = shift;
		
		die "No request in class stash (stash->{req} undef)"
			if ! $class->stash->{req};
			
		my $url = $class->stash->{req}->page_path;
		
		return $url;
	}

	sub redirect_up
	{
		my $class = shift;
		my $count = shift;
		
		@_ = %{ shift || {} } if ref $_[0] eq 'HASH';
		my %args = @_;
		
		die "No request in class stash (stash->{req} undef)"
			if ! $class->stash->{req};
		die "No 'r' object in class->stash'"
			if !$class->stash->{r};
		
		# Get the URL as of $count paths ago
		# E.g. if URL was /foo/bar/boo/baz, and $count=2, then 
		# $url would be /foo/bar
		my $url = $class->stash->{req}->prev_page_path($count);
		
		# Add the %args as ?key=value&key2=value2 pairs
		$url .= '?' if scalar(keys %args) > 0;
		$url .= join('&', map { $_ .'='. url_encode($args{$_}) } keys %args );
		
		# Send redirect to browser
		return $class->stash->{r}->redirect($url);
	}
	
	sub dispatch
	{
		my ($class, $req, $r) = @_;
		
		$class->stash(
			req	=> $req,
			r	=> $r,
		);
		
		$class->setup_routes
			if !$class->router->has_routes;
	
		warn $class.'::dispatch: No routes setup in router(), nothing to dispatch'
			if !$class->router->has_routes;
		
		$class->router->dispatch($req);
	}
	
	sub add_breadcrumb
	{
		my $class = shift;
		my @crumb_args = @_;
		
		return Content::Page::Controller->current_view->breadcrumb_list->push(@_);
	}
	
	sub send_template
	{
		my ($class, $file, $in_view) = @_;

		$in_view = 1 if !defined $in_view;

		return sub {
			my ($class, $req, $r) = @_;
			my $path = $file =~ /\// ? $file : '../tmpl/'.$file;
			my $tmpl = $class->get_template($path);
			die "$class: No template found for $path." if !$tmpl || !ref $tmpl;

			my $key = $file;
			$key =~ s/\./_/g;
			if(!$in_view)
			{
				$tmpl->param('current_'.$key => 1);
				return $r->output_data("text/html", $tmpl->output);
			}

			$class->stash->{view}->tmpl_param('current_'.$key => 1);
			return $class->respond($tmpl->output);
		}
	}

	sub send_redirect
	{
		my ($class, $url) = @_;

		return sub {
			my ($class, $req, $r) = @_;
			return $r->redirect($url);
		}
	}
	
	sub autocomplete_fkclause {}
	
	sub autocomplete_util
	{
		my ($class, $validator, $validate_action, $value, $r) = @_;
		
		$r = $class->stash->{r} if !$r;
		
		my $ctype = 'text/plain';
		if($validate_action eq 'autocomplete')
		{
			my $result = $validator->stringified_list($value, 
					$class->autocomplete_fkclause($validator), #$fkclause
					undef, #$include_objects
					0,  #$start
					10, #$limit (both start and limit have to be defined, not undef - even if zero)
			);
			
			return $class->output_json([ 
				map {
					$_->{text} =~ s/,\s*$//g;
					{
						value => $_->{text},
						id    => $_->{id}
					}
				} @{ $result->{list} || [] }
			]);
		}
		elsif($validate_action eq 'search')
		{
			my $req = $class->stash->{req} || {};
		
			my $result = $validator->stringified_list($value, 
					$class->autocomplete_fkclause($validator), #$fkclause
					undef, #$include_objects
					$req->{start} || 0,  #$start
					$req->{limit} || 10, #$limit (both start and limit have to be defined, not undef - even if zero)
			);
			
			if(ref $result ne 'HASH')
			{
				return $class->output_json({
					total => 0,
					start => $req->{start} || 0,
					limit => $req->{limit} || 10,
					list  => []
				});
			}
			
			return $class->output_json({
				total => $result->{count},
				start => $req->{start} || 0,
				limit => $req->{limit} || 10,
				list  => [ 
					map {
						next if ref ne 'HASH';
						# Hack for "City, ST"
						#$_->{text} =~ s/, (\w{2})$/', '.uc($1)/segi;
						$_->{text} =~ s/,\s*$//g;
						{
							value => $_->{text},
							id    => $_->{id}
						}
					} @{ $result->{list} || [] }
				]
			});
		}
		elsif($validate_action eq 'validate')
		{
			my $value = $validator->validate_string($value);
			my $ref = {
				value => $value,
				text  => $validator->stringify($value)
			};
			return $class->output_json({ result => $ref, err => $@ });
		}
		elsif($validate_action eq 'stringify')
		{
			my $object = $validator->retrieve($value);
			my $ref = {};
			if($object)
			{
				$ref = {
					value	=> $object->id,
					text	=> $object->stringify
				}
			}
			else
			{
				$@ = "Object does not exist";
			}
			
			return $class->output_json({ result => $ref, err => $@ });
		}
		else
		{
			die "Unknown request type '$validate_action'";
			#error("Unknown Validation Request","Unknown validation request '$validate_action'");
		}
	}

	
};
1;

