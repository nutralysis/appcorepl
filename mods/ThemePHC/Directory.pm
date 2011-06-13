use strict;

package PHC::Directory::Family;
{
	use base 'AppCore::DBI';
	
	our @PriKeyAttrs = (
		'extra'	=> 'auto_increment',
		'type'	=> 'int(11)',
		'key'	=> 'PRI',
		readonly=> 1,
		auto	=> 1,
	);
	
	__PACKAGE__->meta(
	{
		# Cheating a bit...
		@Boards::DbSetup::DbConfig,
		table	=> $AppCore::Config::PHC_DIRECTORY_DBTBL || 'directory',
		
		schema	=> 
		[
			{ field => 'familyid',			type => 'int', @PriKeyAttrs },
			{ field	=> 'userid',			type => 'int',	linked => 'AppCore::User' },
			{ field	=> 'spouse_userid',		type => 'int',	linked => 'AppCore::User' },
			{ field => 'first',			type => 'varchar(255)' },
			{ field	=> 'last',			type => 'varchar(255)' },
			{ field	=> 'photo_num',			type => 'varchar(255)' },
			{ field	=> 'incomplete_flag',		type => 'int(1)', null =>0, default =>0 },
			{ field	=> 'birthday',			type => 'varchar(255)' },
			{ field	=> 'cell',			type => 'varchar(255)' },
			{ field => 'email',			type => 'varchar(255)' },
			{ field => 'home',			type => 'varchar(255)' },
			{ field	=> 'address',			type => 'varchar(255)' },
			{ field	=> 'p_cell_dir',		type => 'int(1)', null =>0, default =>1 },
			{ field	=> 'p_cell_onecall',		type => 'int(1)', null =>0, default =>1 },
			{ field	=> 'p_email_dir',		type => 'int(1)', null =>0, default =>1 },
			{ field => 'spouse',			type => 'varchar(255)' },
			{ field => 'spouse_birthday',		type => 'varchar(255)' },
			{ field => 'spouse_cell',		type => 'varchar(255)' },
			{ field => 'spouse_email',		type => 'varchar(255)' },
			{ field	=> 'p_spouse_cell_dir',		type => 'int(1)', null =>0, default =>1 },
			{ field	=> 'p_spouse_cell_onecall',	type => 'int(1)', null =>0, default =>1 },
			{ field	=> 'p_spouse_email_dir',	type => 'int(1)', null =>0, default =>1 },
			{ field => 'anniversary',		type => 'varchar(255)' },
			{ field => 'comments',			type => 'text' },
			{ field	=> 'display',			type => 'varchar(255)' },
			
			{ field => 'timestamp',			type => 'timestamp' },
			
			{ field	=> 'lat',			type => 'float' },
			{ field	=> 'lng',			type => 'float' },
			{ field => 'deleted',			type => 'int', null =>0, default=>1 },
		],	
	});
	
	__PACKAGE__->add_constructor(search_like => '(first like ? or last like ? or spouse like ? or address like ? or email like ? or spouse_email like ?) and deleted!=1 order by last, first');
};

package PHC::Directory::Child;
{
	use base 'AppCore::DBI';
	
	__PACKAGE__->meta(
	{
		# Cheating a bit...
		@Boards::DbSetup::DbConfig,
		table	=> $AppCore::Config::PHC_DIRECTORY_DBTBL || 'directory_kids',
		
		schema	=> 
		[
			{ field => 'childid',			type => 'int', @PHC::Directory::Family::PriKeyAttrs },
			{ field	=> 'familyid',			type => 'int',	linked => 'PHC::Directory::Family' },
			{ field	=> 'child_familyid',		type => 'int',	linked => 'PHC::Directory::Family' },
			{ field	=> 'child_userid',		type => 'int',	linked => 'AppCore::User' },
			{ field => 'first',			type => 'varchar(255)' },
			{ field	=> 'last',			type => 'varchar(255)' },
			{ field	=> 'display',			type => 'varchar(255)' },
			{ field	=> 'cell',			type => 'varchar(255)' },
			{ field => 'email',			type => 'varchar(255)' },
			{ field	=> 'birthday',			type => 'varchar(255)' },
			{ field => 'comments',			type => 'text' },
			
			{ field => 'timestamp',			type => 'timestamp' },
			
			{ field => 'deleted',			type => 'int' },
		],	
	});
};

package PHC::Directory;
{
	# To cache the data in the spreadsheet so we dont have to parse it every reqyest
	use Storable qw/store retrieve/;
	
	sub read_legacy_xls
	{
		my $class = shift;
		my $data_file = shift || 'LegacyData.xls';
		# To read the data spreadsheet
		use Spreadsheet::ParseExcel;
	
		die "File '$data_file' doesn't exist!\n" if !-f $data_file;
		
		my $parser   = Spreadsheet::ParseExcel->new();
		my $workbook = $parser->parse($data_file);
		
		if ( !defined $workbook ) {
			die $parser->error(), ".\n";
		}
		
		my @worksheets = $workbook->worksheets();
		my $worksheet = shift @worksheets;
		
		my ( $row_min, $row_max ) = $worksheet->row_range();
		my ( $col_min, $col_max ) = $worksheet->col_range();
		
		# skip headers
		$row_min ++;
		
		sub xls_value($)
		{
			my $cell = shift;
			if($cell)
			{
				return  $cell->value();
			}
			else
			{
				return undef;
			}
		}
		
		my @entries;
		
		for my $row ( $row_min .. $row_max ) 
		{
			my $col_idx = 0;
			
			my %entry;
			
			$entry{first}			= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{last} 			= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{photo_num}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{incomplete_flag}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{birthday}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{cell}			= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{email}			= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{home}			= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{address}			= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{p_cell_dir}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{p_cell_onecall}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{p_email_dir}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{spouse}			= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{spouse_birthday}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{spouse_cell}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{spouse_email}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{p_spouse_cell_dir}	= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{p_spouse_cell_onecall} 	= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{p_spouse_email}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{anniversary}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			$entry{comments}		= xls_value $worksheet->get_cell( $row, $col_idx++ );
			
			my @kids;
			for(1..8)
			{
				my $name	= xls_value $worksheet->get_cell( $row, $col_idx++ );
				my $bday	= xls_value $worksheet->get_cell( $row, $col_idx++ );
				
				$name =~ s/(^\s+|\s+$)//g;
				push @kids, { name=>$name, bday=>$bday } if $name;
			}
			
			$entry{kids} = \@kids;
			
			if($entry{last})
			{
				#print "$last	/	$entry{first}\n";
				my $name = $entry{first};
				$name .= ' & '.$entry{spouse} if $entry{spouse};
				$name .= ' '.$entry{last};
				
				$entry{display} = $name;
		
				push @entries, \%entry;
				
				if($entry{incomplete_flag})
				{
					#print "Info Sheet: $name\n";
				}
			}
			
		}
		
		@entries = sort { lc $a->{last} cmp lc $b->{last} || lc $a->{first} cmp lc $b->{first} } @entries;
			

		return \@entries;
	}
	
	our $DirectoryData;
	sub clear_cached_dbobjects
	{
		#print STDERR __PACKAGE__.": Clearing cache...\n";
		$DirectoryData = {count=>0, cache=>{}};
	}	
	AppCore::DBI->add_cache_clear_hook(__PACKAGE__);
	
	sub load_directory
	{
		my $class = shift;
		my $start = shift || 0;
		my $search;
		my $length;
		if($start && !@_)
		{
			$search = $start;
			$start = 0;
			$length = 0;
		}
		else
		{
			$search = '';
			$length = shift; 
		}
		
		
		my $cache_key = 'all';
		
		my $count = 0;
		if($length > 0)
		{
			$count = $DirectoryData->{count};
			if(!$count)
			{
				my $sth = PHC::Directory::Family->db_Main->prepare('select count(familyid) from '.PHC::Directory::Family->table.' where deleted!=1');
				$sth->execute();
				$count = $sth->fetchrow;
				$DirectoryData->{count} = $count;
			}
				
			$length = $count - $start if $start + $length > $count;
			
			$start  += 0; # force cast to numbers
			$length += 0; # force cast to numbers
			
			$cache_key = join '', $start, $length;
		}
		elsif($search && length($search) > 0)
		{
			$cache_key = 'search:'.$search;
		}
		
		if($DirectoryData->{cache}->{$cache_key})
		{
			#print STDERR "load_directory: Cache HIT for key '$cache_key'\n";
			return $DirectoryData->{cache}->{$cache_key};
		} 
			
		print STDERR "load_directory: Cache miss for key '$cache_key'\n";
		
			
		my $www_path = $AppCore::Config::WWW_DOC_ROOT;
		
		my @fams;
		if($search)
		{
			my $like = '%'.$search.'%';
			@fams = PHC::Directory::Family->search_like($like,$like,$like,$like,$like,$like);
		}
		else
		{
			@fams = PHC::Directory::Family->retrieve_from_sql('deleted!=1 order by last, first '.($length>0 ? 'limit '.$start.', '.$length : ''));
		}
		
		my @output_list;
		foreach my $fam_obj (@fams)
		{
			my $fam = {};
			$fam->{$_} = $fam_obj->get($_)."" foreach $fam_obj->columns;
			
			my @kids = PHC::Directory::Child->retrieve_from_sql('familyid='.$fam_obj->id.' order by birthday');
			if(@kids)
			{
				my @kid_list;
				foreach my $kid_obj (@kids)
				{
					my $kid = {};
					$kid->{$_} = $kid_obj->get($_)."" foreach $kid_obj->columns;
					push @kid_list, $kid;
				}
				$fam->{kids} = \@kid_list;
			}
			else
			{
				$fam->{kids} = [];
			}
			
			push @output_list, $fam;
			
			if($fam_obj->last)
			{
				#print "$last	/	$fam->{first}\n";
				my $name = $fam->{first};
				$name .= ' & '.$fam->{spouse} if $fam->{spouse};
				$name .= ' '.$fam->{last};
			
		
				if($fam->{photo_num} != '?')
				{
					
					my $photo_file = $AppCore::Config::WWW_ROOT.'/mods/ThemePHC/dir_photos/thumbs/dsc_0'.$fam->{photo_num}.'.jpg';
					$fam->{large_photo} = $AppCore::Config::WWW_ROOT.'/mods/ThemePHC/dir_photos/dsc_0'.$fam->{photo_num}.'.jpg';
					#print STDERR "Primary photo: $photo_file\n";
					if(! -f $www_path.$photo_file)
					{
						$photo_file = $AppCore::Config::WWW_ROOT.'/mods/ThemePHC/dir_photos/thumbs/dsc_'.$fam->{photo_num}.'.jpg';
						$fam->{large_photo} = $AppCore::Config::WWW_ROOT.'/mods/ThemePHC/dir_photos/dsc_'.$fam->{photo_num}.'.jpg';
						#print STDERR "Setting secondary photo path: $photo_file (due to bad $www_path$photo_file)\n";
					}
					if(!-f $photo_file)
					{
						#print STDERR "No photo at: $photo_file\n";
						if($fam->{photo_num})
						{
							#my @test = `ls dir_photos/dsc_*$fam->{photo_num}.jpg`;
							#@test = `ls dir_photos/dsc_$fam->{photo_num}.jpg` if !@test;
							#print "$name:\tWarning: '$fam->{photo_num}' not found, possibilities:\n",
							#	join @test;
						}
						else
						{
							#print "No photo num at all: $name";
						}
					}
					
					$fam->{photo} = $photo_file ? $photo_file: '';
					
					$fam->{comments} =~ s/([^\s]+\@[^\s]+\.\w+)/<a href='mailto:$1'>$1<\/a>/g;
				}
				else
				{
					#print "Missing Photo: $name\n";
				}
				
				#push @entries, \%entry;
				
				if($fam->{incomplete_flag})
				{
					#print "Info Sheet: $name\n";
				}
			}
			
			$fam->{spouse_user} = $fam_obj->spouse_userid ? $fam_obj->spouse_userid->user : '';
			$fam->{user} = $fam_obj->userid ? $fam_obj->userid->user : ''; 
			
			# Make the jQuery template function happy on the client side
			$fam->{photo}       = '' if !$fam->{photo};;
			$fam->{large_photo} = '' if !$fam->{large_photo};
			$fam->{address}     = '' if !$fam->{address};
			$fam->{comments_html} = $fam->{comments} ? $fam->{comments} : ""; # jQuery tmpl plugin parses the '_html' differently
			
			# Make the jQuery template function happy on the client side
			foreach(keys %$fam)
			{
				$fam->{$_} = "" if !defined $fam->{$_};
			} 
		}
		
# 		my $result = \@output_list;
# 		if($length > 0)
# 		{
			my $result = 
			{
				count	=> $count ? $count : scalar @output_list,
				list	=> \@output_list, 
				start	=> $start,
				length	=> $length ? $length : scalar @output_list,
				search	=> $search,
			};
#		}
		
		$DirectoryData->{cache}->{$cache_key} = $result;
		
		return $result;
	};

};


package ThemePHC::Directory::UserActionHook;
{
	use User;
	use base 'User::ActionHook';
	
	__PACKAGE__->register(User::ActionHook::EVT_ANY);
	
	sub hook
	{
		my ($self,$event,$args) = @_;
		
		print STDERR __PACKAGE__.": Event: '$event'\n";
	}
};


package ThemePHC::Directory;
{
	# Inherit both the AppCore::Web::Module and Page Controller.
	# We use the Page::Controller to register a custom
	# page type for user-created board pages  
	use base qw{
		AppCore::Web::Module
		Content::Page::Controller
	};
	
	use Content::Page;
	
	# Register our pagetype
	__PACKAGE__->register_controller('PHC Family Directory','PHC Family Directory',1,0);  # 1 = uses page path,  0 = doesnt use content
	
	use Data::Dumper;
	#use DateTime;
	use AppCore::Common;
	use JSON qw/encode_json/;
	
	my $MGR_ACL = [qw/Pastor/];
	
	sub apply_mysql_schema
	{
		my $self = shift;
		my @db_objects = qw{
			PHC::Directory::Family
			PHC::Directory::Child
		};
		AppCore::DBI->mysql_schema_update($_) foreach @db_objects;
	}
	
	sub new
	{
		my $class = shift;
		
		my $self = bless {}, $class;
		
		return $self;
	};
# 	
	# Implemented from Content::Page::Controller
	sub process_page
	{
		my $self = shift;
		my $type_dbobj = shift;
		my $req  = shift;
		my $r    = shift;
		my $page_obj = shift;
		
		# Change the 'location' of the webmodule so the webmodule code thinks its located at this page path
		# (but %%modpath%% will return /ThemeBryanBlogs for resources such as images)
		my $new_binpath = $AppCore::Config::DISPATCHER_URL_PREFIX . $req->page_path; # this should work...
		#print STDERR __PACKAGE__."->process_page: new binpath: '$new_binpath'\n";
		$self->binpath($new_binpath);
		
		## Redispatch thru the ::Module dispatcher which will handle calling main_page()
		#return $self->dispatch($req, $r);
		return $self->dir_page($req,$r);
		
# 		# Get a view module from the template based on view code so the template can choose to dispatch a view to a different object if needed
# 		my $view = $self->get_view($view_code,$r);
# 		
# 		# Pass the view code onto the view output function so that it can aggregate different view types into one module
# 		$view->output($page_obj,$r,$view_code);
	};
	
	sub dir_page
	{
		my $self = shift;
		my ($req,$r) = @_;
		
 		my $user = AppCore::Common->context->user;
		if(!$user || !$user->check_acl(['Can-See-Family-Directory','Pastor']))
		{
			my $tmpl = $self->get_template('directory/denied.tmpl');
			return $r->output($tmpl);
		}
		
		#my $sub_page = shift @$path;
		my $sub_page = $req->next_path;
		if($sub_page eq 'delete')
		{
			AppCore::AuthUtil->require_auth(['ADMIN','Pastor']);
			
			my $fam = $req->familyid;
			
			my $entry = PHC::Directory::Family->retrieve($fam);
			return $r->error("No Such Family","Sorry, the family ID you gave does not exist") if !$entry;
			
			$entry->deleted(1);
			$entry->update;
			
			return $r->redirect($self->binpath);
		}
		elsif($sub_page eq 'claim')
		{
			# Must be logged in to claim a family
			AppCore::AuthUtil->require_auth();
			
			my $fam = $req->familyid;
			
			my $entry = PHC::Directory::Family->retrieve($fam);
			return $r->error("No Such Family","Sorry, the family ID you gave does not exist") if !$entry;
			
			my $my_entry;
			if($user)
			{
				$my_entry = PHC::Directory::Family->by_field(userid => $user);
				$my_entry = PHC::Directory::Family->by_field(spouse_userid => $user) if !$my_entry;
			}
			
			if($my_entry && $my_entry->id != $fam)
			{
				return $r->error("You've Already Claimed a Family","Sorry, you've already claimed a family! Contact the webmaster for more help.");
			}
			
			if($entry->userid && $entry->userid->id && $entry->spouse_userid && $entry->spouse_userid->id)
			{
				return $r->error("Both Spouses Already Claimed","The user account for both spouses have already been claimed. Contact the webmaster for more help."); 
			}
			
			my $edit_url = $self->module_url('/edit?familyid='.$fam);
			
			if(my $type = $req->{claim_type})
			{
				# they saw the form, now update and redirect to edit
				
				if($type eq 'spouse')
				{
					$entry->spouse_userid($user);
					$entry->update;
					return $r->redirect($edit_url);
				}
				else
				{
					# two spouses, but primary NOT claimed, so assign primary
					$entry->userid($user);
					$entry->update;
					return $r->redirect($edit_url);
				}
			}
			
			if($entry->spouse && $entry->first)
			{
				if($entry->userid && !$entry->spouse_userid)
				{
					# two spouses, but primary claimed, so assign secondary
					$entry->spouse_userid($user);
					$entry->update;
					return $r->redirect($edit_url);
				}
				elsif($entry->spouse_userid && !$entry->userid)
				{
					# two spouses, but primary NOT claimed, so assign primary
					$entry->userid($user);
					$entry->update;
					return $r->redirect($edit_url);
				}
				
				# neither account claimed, show form
				my $tmpl = $self->get_template('directory/claim.tmpl');
			
				$tmpl->param($_ => $entry->get($_)) foreach $entry->columns;
				
				my $view = Content::Page::Controller->get_view('sub',$r);
				$view->breadcrumb_list->push('Claim Family',$self->module_url('/claim?familyid='.$fam),0);
				$view->output($tmpl);
				return $r;
			}
			elsif($entry->first)
			{
				# Only one person in family, claim first account and redirect to edit
				$entry->userid($user);
				$entry->update;
				
				return $r->redirect($edit_url);
			}
			else
			{
				return $r->error("No Names","Wiered - no names on this account. Contact the webmaster for more help.");
			}
			
		}
		elsif($sub_page eq 'edit')
		{
			my $fam = $req->familyid;
			
			my $entry = PHC::Directory::Family->retrieve($fam);
			return $r->error("No Such Family","Sorry, the family ID you gave does not exist") if !$entry;
			
			my $admin = $user && $user->check_acl([qw/ADMIN Pastor/]) ? 1:0;
			my $can_edit = $admin || $entry->userid == $user || $entry->spouse_userid == $user;
			return $r->error("Permission Denied","Sorry, you don't have permission to edit this family") if !$can_edit;
			
			my $tmpl = $self->get_template('directory/edit.tmpl');
			
			$tmpl->param($_ => $entry->get($_)) foreach $entry->columns;
			
			my @kids = PHC::Directory::Child->search(familyid => $entry->id);
			foreach my $kid (@kids)
			{
				$kid->{$_} = $kid->get($_) foreach $kid->columns;
			}
			$tmpl->param(kids => \@kids);
			
			my $admin = $user && $user->check_acl([qw/ADMIN Pastor/]) ? 1:0;
			$tmpl->param(is_admin => $admin);
			
			$tmpl->param(users => AppCore::User->tmpl_select_list($entry->userid,1));
			$tmpl->param(spouse_users => AppCore::User->tmpl_select_list($entry->spouse_userid,1));
			
			my $view = Content::Page::Controller->get_view('sub',$r);
			$view->breadcrumb_list->push('Edit Family',$self->module_url('/edit?familyid='.$fam),0);
			$view->output($tmpl);
			return $r;
		}
		elsif($sub_page eq 'new')
		{
			AppCore::AuthUtil->require_auth(['ADMIN','Pastor']);
			
			my $tmpl = $self->get_template('directory/edit.tmpl');
			
			my $admin = $user && $user->check_acl([qw/ADMIN Pastor/]) ? 1:0;
			$tmpl->param(is_admin => $admin);
			
			$tmpl->param(users => AppCore::User->tmpl_select_list(undef,1));
			$tmpl->param(spouse_users => AppCore::User->tmpl_select_list(undef,1));
			
			my $view = Content::Page::Controller->get_view('sub',$r);
			$view->breadcrumb_list->push('New Family',$self->module_url('/new'),0);
			$view->output($tmpl);
			return $r;
			
		}
		elsif($sub_page eq 'post')
		{
			my $fam = $req->familyid;
			
			my $admin = $user && $user->check_acl([qw/ADMIN Pastor/]) ? 1:0;
			
			my $entry = PHC::Directory::Family->retrieve($fam);
			if(!$entry)
			{
				if($admin)
				{
					$entry = PHC::Directory::Family->insert({ last => $req->last });
				}
				else
				{
					return $r->error("No Such Family","Sorry, the family ID you gave does not exist") if !$entry;
				} 
			}
			
			my $can_edit = $admin || $entry->userid == $user || $entry->spouse_userid == $user;
			return $r->error("Permission Denied","Sorry, you don't have permission to edit this family") if !$can_edit;
			
			my @cols = qw/
				first
				last
				birthday
				cell
				email
				home
				address
				p_cell_dir
				p_cell_onecall
				p_email_dir
				spouse
				spouse_birthday
				spouse_cell
				spouse_email
				p_spouse_cell_dir
				p_spouse_cell_onecall
				p_spouse_email_dir
				anniversary
				comments
			/;
			
			my $admin = $user && $user->check_acl([qw/ADMIN Pastor/]) ? 1:0;
			if($admin)
			{
				push @cols, qw/userid spouse_userid photo_num/;
			}
			
			foreach my $col (@cols)
			{
				#print STDERR "Checking col: $col\n";
				$entry->set($col, $req->$col) if defined $req->$col;
			}
			
			my $name = $entry->first;
			$name .= ' & '.$entry->spouse if $entry->spouse;
			$name .= ' '.$entry->last;
			
			$entry->display if $name ne $entry->display;
			
			$entry->update;
			
			my @kids = PHC::Directory::Child->search(familyid => $entry->id);
			if(@kids)
			{
				foreach my $kid (@kids)
				{
					my $name = $req->{'name_'.$kid->id};
					$kid->display($name) if $kid->display ne $name;
					
					my $bday = $req->{'bday_'.$kid->id};
					$kid->birthday($bday) if $kid->birthday ne $bday;
					
					$kid->update if $kid->is_changed;
				}
			}
			
			if($req->{name_new})
			{
				PHC::Directory::Child->insert({
					familyid	=> $entry->id,
					display 	=> $req->{name_new},
					birthday	=> $req->{bday_new},
				});
			}
			
			if($req->{add_another})
			{
				return $r->redirect($self->binpath.'/edit?familyid='.$entry->id.'#add_another');
			}
			else
			{
				return $r->redirect($self->binpath.'#'.$entry->display);
			}
			
		}
		else
		{
	
			
			my $map_view = $req->{map} eq '1';
			
			my $tmpl = $self->get_template('directory/'.( $map_view? 'map.tmpl' : 'main.tmpl' ));
			
			my $start = $req->{start} || 0;
			
			$start =~ s/[^\d]//g;
			$start = 0 if !$start || $start<0;
			
			my $length = 10;
			
			if($req->{search} && $req->output_fmt ne 'json')
			{
				# Require at least 3 letters if not using json
				return $r->error("At least 3 letters","You need at least 3 letters to search") if length $req->{search} < 3;
			}
			
			#@directory = @directory[$start .. $start+$count];
			my $directory_data = PHC::Directory->load_directory($req->{search} ? $req->{search} : ($start, $length));
			
			
			my $my_entry;
			if($user)
			{
				$my_entry = PHC::Directory::Family->by_field(userid => $user);
				$my_entry = PHC::Directory::Family->by_field(spouse_userid => $user) if !$my_entry;
			}
			#$my_entry = 0;
			my @directory = @{$directory_data->{list}};
			my $bin = $self->binpath;
			#@directory = grep { $_->{last} =~ /(Bryan)/ } @directory if $map_view;
			my $admin = $user && $user->check_acl([qw/ADMIN Pastor/]) ? 1:0;
			my $userid = $user ? $user->id : undef;
			foreach my $entry (@directory)
			{
				$entry->{can_edit} = $admin || ($userid && ($entry->{userid} == $userid || $entry->{spouse_userid} == $userid));
				$entry->{has_account} = $my_entry ? 1:0; # relevant only if !can_edit
				$entry->{is_admin} = $admin;
				$entry->{bin} = $bin;
			}
			
			if($req->output_fmt eq 'json')
			{
				my $json = encode_json($directory_data);
				return $r->output_data("application/json", $json); # if $req->output_fmt eq 'json';
				#return $r->output_data("text/plain", $json);
			}
			
			my $count = $directory_data->{count};
			$start = $directory_data->{start};
			$length = $directory_data->{length};
			$length = 1 if !$length;
			
			$tmpl->param(count	=> $count);
			$tmpl->param(pages	=> int($count / $length));
			$tmpl->param(cur_page	=> int($start / $length) + 1);
			$tmpl->param(next_start	=> $start + $length);
			$tmpl->param(prev_start	=> $start - $length);
			$tmpl->param(is_end	=> $start + $length >= $count);
			$tmpl->param(is_start	=> $start <= 0);
			$tmpl->param(start	=> $start);
			$tmpl->param(length	=> $length);
			$tmpl->param(next_idx	=> $start + $length);
			$tmpl->param(search	=> $req->{search});
			$tmpl->param(is_admin	=> $admin);
			
			#die Dumper \@directory;
			
			$tmpl->param(entries => \@directory);
			
			#$r->output($tmpl);
			my $view = Content::Page::Controller->get_view('sub',$r)->output($tmpl);
			return $r;
		}
	}
	
	
}


1;