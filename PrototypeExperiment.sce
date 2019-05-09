# -------------------------- Header Parameters --------------------------
scenario = "Prototype";

write_codes = EXPARAM( "Send Port Codes" );
screen_width_distance = EXPARAM( "Display Width" );
screen_height_distance = EXPARAM( "Display Height" );
screen_distance = EXPARAM( "Viewing Distance" );

default_background_color = EXPARAM( "Background Color" );
default_font = EXPARAM( "Non-Stimulus Font" );
default_font_size = EXPARAM( "Non-Stimulus Font Size" );
default_text_color = EXPARAM( "Non-Stimulus Font Color" );

response_matching = simple_matching;
active_buttons = 2;
target_button_codes = 1,2;
response_logging = EXPARAM( "Response Logging" );

stimulus_properties =
	event_name, string,
	prac_type, string,
	trial_number, number,
	stim_type, string,
	stim_cond, string,
	ISI_duration, number,
	p_code, number,
	stim_file, string;
event_code_delimiter = ";";

# ------------------------------- SDL Part ------------------------------
begin;

# instruction page
# TODO: need to have xml text info source using Magyar (HU) and English (EN) language. HU is the default.
trial{
	trial_type = first_response;
	trial_duration = forever;
	picture{
		text { 
			caption = "Instructions";
			preload = false;
		} instruct_text;
		x = 0; 
		y = 0;
	} instruct_pic;
} instruct_trial;

# stimuli object
trial {
	stimulus_event {
		picture {} ISI_pic;
		code = "ISI";
	} ISI_event;
} ISI_trial;

# stimuli masking
trial {
	clear_active_stimuli = false;
	stimulus_event {
		picture {
			ellipse_graphic {
				ellipse_height = EXPARAM( "Fixation Point Size" );
				ellipse_width = EXPARAM( "Fixation Point Size" );
				color = EXPARAM( "Fixation Point Color" );
			} fix_circ;
			x = 0;
			y = 0;
		} stim_pic;
		response_active = true;
		code = "Stim";
	} stim_event;
} stim_trial;

# rest trial period
trial {
	trial_duration = forever;
	trial_type = first_response;
	
	stimulus_event {
		picture {
			text {
				caption = "Rest";
				preload = false;
			} rest_text;
			x = 0;
			y = 0;
		};
		code = "Rest";
	} rest_event;
} rest_trial;

# start trial

trial {
	stimulus_event {
		picture {
			text {
				caption = "Ready";
				preload = false;
			} ready_text;
			x = 0;
			y = 0;
		};
	} ready_event;
} ready_trial;

# study trial
trial {
	stimulus_event {
		picture {} test_pic;
		code = "Study";
	} study_event;
} study_trial;

trial {
	stimulus_event {
		picture {} ITI_pic;
		code = "ITI";
	} ITI_event;
} ITI_trial;

# ----------------------------- PCL Program -----------------------------
begin_pcl;

# external library for specific helper function/tools
include_once "Library/lib_utilities.pcl";
include_once "Library/lib_visual_utilities.pcl";

# --- CONSTANTS --- #

string STIM_EVENT_CODE = "Stimulus";
string PRACTICE_TYPE_PRACTICE = "Practice";
string PRACTICE_TYPE_MAIN = "Main";

# Button Up and Down
string IN_BUTTON_LABEL = "[IN_BUTTON]";
string OUT_BUTTON_LABEL = "[OUT_BUTTON]";

string LOG_ACTIVE = "log_active";

int IN_IDX = 1;
int OUT_IDX = 2;

int TYPE_IDX = 1;
int COND_IDX = 2;
int STIM_IDX = 3;

int CORR_BUTTON = 201;
int INCORR_BUTTON = 202;

string INSIDE_COND = "Inside";
string OUTSIDE_COND = "Outside";

string CHARACTER_WRAP = "Character";

int PORT_CODE_PREFIX = 100;

int MIN_OBJECTS = 3; # Minimum total grid size
int rows = 3;
int columns = 3;
double line_width = 0.5;

int retention_interval = 50*1000;#ms
trial_refresh_fix( ITI_trial, retention_interval );


# --- Set up fixed stimulus parameters ---

string language = parameter_manager.get_string( "Language" );
language_file lang = load_language_file( scenario_directory + language + ".xml" );
bool char_wrap = ( get_lang_item( lang, "Word Wrap Mode" ).lower() == CHARACTER_WRAP.lower() );
double font_size = parameter_manager.get_double( "Non-Stimulus Font Size" );

# Set up the rest trial 
int rest_dur = parameter_manager.get_int( "Rest Break Duration" );
if ( rest_dur > 0 ) then
	rest_trial.set_type( rest_trial.FIXED );
	trial_refresh_fix( rest_trial, rest_dur );
	string rest_cap = get_lang_item( lang, "Timed Rest Caption" );
	full_size_word_wrap( rest_cap, font_size, char_wrap, rest_text );
else
	string rest_cap = get_lang_item( lang, "Untimed Rest Caption" );
	full_size_word_wrap( rest_cap, font_size, char_wrap, rest_text );
end;

# Add fixation to ISI
if ( parameter_manager.get_bool( "Show Fixation Point During ISI" ) ) then
	ISI_pic.add_part( fix_circ, 0, 0 );
end;

# Set the target and nontarget buttons
begin
	array<int> b_codes[2];
	b_codes.fill( 1, 0, INCORR_BUTTON, 0 );
	response_manager.set_button_codes( b_codes );
	b_codes.fill( 1, 0, CORR_BUTTON, 0 );
	response_manager.set_target_button_codes( b_codes );
end;

# Change response logging
if ( parameter_manager.get_string( "Response Logging" ) == LOG_ACTIVE ) then
	ISI_trial.set_all_responses( false );
	stim_trial.set_all_responses( false );
end;

# --- Stimulus setup

# setup 3x3 GRID location
if ( rows * columns < MIN_OBJECTS ) then
	exit( "Error: Grid must contain at least " + string( MIN_OBJECTS ) + " elements. Increase 'Object Rows' or 'Object Columns'" );
end;


array<bitmap> all_stim[2][0][0];
parameter_manager.get_bitmaps( "Inside Condition Images", all_stim[IN_IDX] );
parameter_manager.get_bitmaps( "Outside Condition Images", all_stim[OUT_IDX] );

array<bitmap> prac_bmps[2][0];
parameter_manager.get_bitmaps( "Inside Practice Images", prac_bmps[IN_IDX] );
parameter_manager.get_bitmaps( "Outside Practice Images", prac_bmps[OUT_IDX] );


# setup stimulus picture location
array<double> slot_dims[2];

double d_width = display_device.custom_width();
double d_height = display_device.custom_height();

slot_dims[1] = d_width / double( columns );
slot_dims[2] = d_height / double( rows );

array<bitmap> images[0];
parameter_manager.get_bitmaps( "Stimuli", images );
loop
	bool scale_images = parameter_manager.get_bool( "Resize Images to Fit" );
	int i = 1
until
	i > images.count()
begin
	double bmp_height = images[i].height();
	double bmp_width = images[i].width();
	
	double width_ratio = bmp_width / slot_dims[1];
	double height_ratio = bmp_height / slot_dims[2];
	
	if ( scale_images ) then
		if ( width_ratio > height_ratio ) && ( width_ratio > 1.0 ) then
			images[i].set_load_size( 0.0, slot_dims[1], images[i].SCALE_TO_WIDTH );
		elseif ( height_ratio > width_ratio ) && ( height_ratio > 1.0 ) then
			images[i].set_load_size( slot_dims[2], 0.0, images[i].SCALE_TO_HEIGHT );
		end;
		images[i].load();
	else
		if ( width_ratio > 1.0 ) || ( height_ratio > 1.0 ) then
			string filename = images[i].filename();
			exit( "Error: The image file " + filename + " is too large. Reduce image size, increase grid dimensions, or set 'Resize Images to Fit' to 'True'" );
		end;
	end;
	i = i + 1;
end;


#setup 9 location grid
array<double> grid_locs[0][0];
double total_width = ( slot_dims[1] * double( columns ) ) + ( line_width * double( columns - 1 ) );
double total_height = ( slot_dims[2] * double( rows ) ) + ( line_width * double( rows - 1 ) );

loop
	int row = 1;
	double start_x = ( -total_width * 0.5 ) + slot_dims[1]/2.0;
	double start_y = ( total_height * 0.5 ) - slot_dims[2]/2.0;
	double curr_x = start_x;
	double curr_y = start_y;
until
	row > rows
begin
	loop
		int column = 1
	until
		column > columns
	begin
		array<double> temp[2];
		temp[1] = curr_x;
		temp[2] = curr_y;
		
		grid_locs.add( temp );
		
		curr_x = curr_x + slot_dims[1] + line_width;
		column = column + 1;
	end;
	
	curr_x = start_x;
	curr_y = curr_y - slot_dims[2] - line_width;
	row = row + 1;
end;

array<line_graphic> outlines[rows * columns];
line_graphic sel_box = new line_graphic();
rgb_color cursor_color = parameter_manager.get_color( "Cursor Color" );
rgb_color outline_color = parameter_manager.get_color( "Outline Color" );

# Get the condition (sub-array) counts
array<int> cond_counts[2];
cond_counts[IN_IDX] = all_stim[IN_IDX].count();
cond_counts[OUT_IDX] = all_stim[OUT_IDX].count();

# Get the requested trial counts
array<int> trial_cts[2];
trial_cts[IN_IDX] = parameter_manager.get_int( "Inside Trials per Condition" );
trial_cts[OUT_IDX] = parameter_manager.get_int( "Outside Trials per Condition" );

# Get the specified condition names. Make sure there are the same number of names as subarrays
array<string> cond_names[2][0];
parameter_manager.get_strings( "Inside Condition Names", cond_names[IN_IDX] );
parameter_manager.get_strings( "Outside Condition Names", cond_names[OUT_IDX] );

if ( cond_names[IN_IDX].count() != cond_counts[IN_IDX] ) then
	exit( "Error: There must be the same number of elements in 'Inside Condition Names' as subarrays in 'Inside Condition Images'" );
end;
if ( cond_names[OUT_IDX].count() != cond_counts[OUT_IDX] ) then
	exit( "Error: There must be the same number of elements in 'Outside Conditon Names' as subarrays in 'Outside Condition Images'" );
end;

# --- Subroutines --- #

ellipse_graphic cursor = new ellipse_graphic();

test_pic.add_part( sel_box, 0, 0 );
test_pic.add_part( cursor, 0, 0 );
bool cursor_on = true;

sub
	remove_cursor_parts
begin
	if ( cursor_on ) then
		test_pic.remove_part( test_pic.part_count() );
		test_pic.remove_part( test_pic.part_count() );
		cursor_on = false;
	end;
end;

# --- sub present_instructions 

sub
	present_instructions( string instruct_string )
begin
	full_size_word_wrap( instruct_string, font_size, char_wrap, instruct_text );
	instruct_trial.present();
	default.present();
end;

# --- sub get_filename

sub
	string get_filename( bitmap this_bitmap )
begin
	string temp_string = this_bitmap.filename();
	
	int last_slash = 1;
	loop
	until
		temp_string.find( "\\", last_slash ) == 0
	begin
		last_slash = last_slash + 1;
	end;
	
	temp_string = temp_string.substring( last_slash, temp_string.count()-last_slash+1 );
	
	return temp_string
end;

# --- sub ready_set_go ---

int ready_dur = parameter_manager.get_int( "Ready-Set-Go Duration" );
trial_refresh_fix( ready_trial, ready_dur );

array<string> ready_caps[3];
ready_caps[1] = get_lang_item( lang, "Ready Caption" );
ready_caps[2] = get_lang_item( lang, "Set Caption" );
ready_caps[3] = get_lang_item( lang, "Go Caption" );

sub
	ready_set_go
begin
	if ( ready_dur > 0 ) then
		loop
			int i = 1
		until
			i > ready_caps.count()
		begin
			full_size_word_wrap( ready_caps[i], font_size, char_wrap, ready_text );
			ready_trial.present();
			i = i + 1;
		end;
	end;
end;

# --- sub get_port_code

# If they aren't using 2 x 2 design, then default to generic
bool generic_codes = false;
if ( cond_counts[IN_IDX] != 2 ) || ( cond_counts[OUT_IDX] != 2 ) then
	generic_codes = true;
else
	loop
		int i = 1
	until
		i > all_stim.count()
	begin
		loop
			int j = 1
		until
			j > all_stim[i].count()
		begin
			if ( all_stim[i][j].count() > 50 ) then
				generic_codes = true;
			end;
			j = j + 1;
		end;
		i = i + 1;
	end;
end;

# If there are more than 100 conditions, then exit	
if ( cond_counts[IN_IDX] > 100 ) || ( cond_counts[OUT_IDX] > 100 ) then
	exit( "Error: There must be fewer than 100 conditions (subarrays) specified." );
end;

sub
	int get_port_code( int stim_type, int stim_cond, int stim_number )
begin
	int this_p_code = stim_number;
	if ( generic_codes ) then
		this_p_code = stim_cond;
	elseif ( stim_cond != IN_IDX ) then
		this_p_code = this_p_code + all_stim[IN_IDX][stim_cond].count();
	end;
	if ( stim_type == OUT_IDX ) then
		this_p_code = this_p_code + PORT_CODE_PREFIX;
	end;
	return this_p_code
end;

# --- sub string_replace

array<string> button_names[2];
button_names[1] = parameter_manager.get_string( "Response Button 1 Name" );
button_names[2] = parameter_manager.get_string( "Response Button 2 Name" );
int obj_button = parameter_manager.get_int( "Response Button Mapping" );

sub
	string string_replace( string start_string )
begin
	string rval = start_string;
	rval = rval.replace( IN_BUTTON_LABEL, button_names[obj_button] );
	rval = rval.replace( OUT_BUTTON_LABEL, button_names[(obj_button%2)+1] );
	return rval
end;

# --- sub show_trial_sequence

# Instructions
string instructions = string_replace( get_lang_item( lang, "Instructions" ) );
string reminder_cap = string_replace( get_lang_item( lang, "Reminder Caption" ) );

# Initialize some other values
int trials_per_rest = parameter_manager.get_int( "Trials Between Rest Breaks" );
bool repeat_stim = parameter_manager.get_bool( "Repeat Stimuli" );
array<int> ISI_range[0];
parameter_manager.get_ints( "ISI Range", ISI_range );
if ( ISI_range.count() != 2 ) then
	exit( "Error: Exactly two values must be specified in 'ISI Range'" );
end;

# Get the requested stimulus durations, exit if none
int stim_dur = parameter_manager.get_int( "Stimulus Duration" );
trial_refresh_fix( stim_trial, stim_dur );

array<int> corr_buttons[2];
corr_buttons[IN_IDX] = parameter_manager.get_int( "Response Button Mapping" );
corr_buttons[OUT_IDX] = ( corr_buttons[IN_IDX] % 2 ) + 1;

array<string> type_names[2];
type_names[IN_IDX] = INSIDE_COND;
type_names[OUT_IDX] = OUTSIDE_COND;

sub
	show_trial_sequence( array<int,2>& trial_sequence, string prac_check )
begin
	# Get ready!
	ready_set_go();
	
	# Start with an ISI
	trial_refresh_fix( ISI_trial, random( ISI_range[1], ISI_range[2] ) );
	ISI_trial.present();
	
	# Loop to present trials
	loop
		int i = 1
	until
		i > trial_sequence.count()
	begin
		# Get some values for this trial
		int this_type = trial_sequence[i][TYPE_IDX];
		int this_cond = trial_sequence[i][COND_IDX];
		int this_stim = trial_sequence[i][STIM_IDX];
		string cond_name = cond_names[this_type][this_cond];
		string filename = get_filename( all_stim[this_type][this_cond][this_stim] );
		
		#term.print_line( string( this_type ) + " " + string( this_cond ) + " " + string( this_stim ) );
		# Set the stimulus
		if ( prac_check == PRACTICE_TYPE_PRACTICE ) then
			cond_name = PRACTICE_TYPE_PRACTICE;
			stim_pic.set_part( 1, prac_bmps[this_type][this_stim] );
			filename = get_filename( prac_bmps[this_type][this_stim] );
		else
			stim_pic.set_part( 1, all_stim[this_type][this_cond][this_stim] );
		end;
		
		# Set the ISI duration
		int this_isi = random( ISI_range[1], ISI_range[2] );
		trial_refresh_fix( ISI_trial, this_isi );
		
		# Set the target button
		stim_event.set_target_button( corr_buttons[this_type] );
		
		# Set port code
		int p_code = get_port_code( this_type, this_cond, this_stim );
		stim_event.set_port_code( p_code );
		
		# Set the event code
		stim_event.set_event_code(
			STIM_EVENT_CODE + ";" +
			prac_check + ";" +
			string( i ) + ";" +
			type_names[this_type] + ";" +
			cond_name + ";" +
			string( this_isi ) + ";" +
			string( p_code ) + ";" +
			filename
		);
		
		# Show the trial
		stim_trial.present();
		ISI_trial.present();
		
		# Show the rest
		if ( trials_per_rest > 0 ) && ( prac_check == PRACTICE_TYPE_MAIN ) then
			if ( i % trials_per_rest == 0 ) && ( i < trial_sequence.count() ) then
				rest_trial.present();
				present_instructions( reminder_cap );
				ready_set_go();
			end;
		end;
		
		# Increment
		i = i + 1;
	end;
end;

# Sub show study simple image
sub
	show_study
begin
	# Randomize the image set
	images.shuffle();
	
	remove_cursor_parts();
		
	# Reset the grid stimuli to the new randomized images
	loop
		int i = 1
	until
		i > grid_locs.count()
	begin
		test_pic.set_part( i, images[i] );
		i = i + 1;
	end;
	
	# Show study trial
	study_trial.present();
	ITI_trial.present();
end;

# --- Trial & Condition Sequence --- #

array<int> cond_array[0][0];
array<int> prac_cond_array[0][0];

# Build the trial sequence
begin
	# Randomize the stimulus order & check if there are enough stimuli (if they don't want to repeat)
	bool randomize_stim = parameter_manager.get_bool( "Randomize Stimulus Order" );
	
	# Now we'll set up the order of picture #s
	array<int> stim_order[2][0][0];
	loop
		int i = 1
	until
		i > all_stim.count()
	begin
		stim_order[i].resize( all_stim[i].count() );
		int trial_ct = trial_cts[i];
		
		# For each condition/type, set a picture order
		# This order can be the same as the pictures are entered in the param manager
		# or randomized. Note if pictures are repeated, the entire set for that 
		# condition is shown before any picture is repeated.
		loop
			int j = 1
		until
			j > all_stim[i].count()
		begin
			array<int> stim_indices[all_stim[i][j].count()];
			stim_indices.fill( 1, 0, 1, 1 );
			
			# Break if they don't have enough stimuli & don't want to repeat stim
			if ( !repeat_stim ) then
				if ( stim_indices.count() < trial_ct ) then
					exit( "Error: Not enough stimuli specified. Add more stimuli or reduce the number of trials per condition." );
				end;
			end;

			loop
			until
				stim_order[i][j].count() >= trial_ct
			begin
				if ( randomize_stim ) then
					stim_indices.shuffle();
				end;
				stim_order[i][j].append( stim_indices );
			end;
			stim_order[i][j].resize( trial_ct );
			
			j = j + 1;
		end;
		
		i = i + 1;
	end;
			
	# Now build the trial sequence
	loop
		int i = 1
	until
		i > stim_order.count()
	begin
		loop
			int j = 1
		until
			j > stim_order[i].count()
		begin
			loop
				int k = 1
			until
				k > stim_order[i][j].count()
			begin
				array<int> temp[3];
				temp[TYPE_IDX] = i;
				temp[COND_IDX] = j;
				
				cond_array.add( temp );
				k = k + 1;
			end;
			j = j + 1;
		end;
		i = i + 1;
	end;

	cond_array.shuffle();
	array<int> ctrs[2][0];
	ctrs[1].resize( all_stim[1].count() );
	ctrs[2].resize( all_stim[2].count() );
	loop
		int i = 1
	until
		i > cond_array.count()
	begin
		int this_type = cond_array[i][TYPE_IDX];
		int this_cond = cond_array[i][COND_IDX];
		if ( ctrs[this_type][this_cond] == 0 ) then
			ctrs[this_type][this_cond] = 1;
		end;
		int this_stim = ctrs[this_type][this_cond];
		cond_array[i][STIM_IDX] = stim_order[this_type][this_cond][this_stim];
		
		ctrs[this_type][this_cond] = ctrs[this_type][this_cond] + 1;
		i = i + 1;
	end;
	
	# Build a practice trial sequence
	int prac_trials = parameter_manager.get_int( "Practice Trials" );
	array<int> temp_prac_array[0][0];
	loop
		int i = 1
	until
		i > prac_bmps.count()
	begin
		loop
			int j = 1
		until
			j > prac_bmps[i].count()
		begin
			array<int> temp[3];
			temp[TYPE_IDX] = i;
			temp[COND_IDX] = 1;
			temp[STIM_IDX] = j;
				
			temp_prac_array.add( temp );
			
			j = j + 1;
		end;
		i = i + 1;
	end;
	
	loop
	until
		prac_cond_array.count() >= prac_trials
	begin
		prac_cond_array.append( temp_prac_array );
	end;
	prac_cond_array.resize( prac_trials );
	prac_cond_array.shuffle();
	
	
	#start image show
	
	# Set up the polygon that'll get used for outlined boxes
	array<double> outline_ends[0][0];
	array<double> temp[2];
	
	temp[1] = -( slot_dims[1]/2.0 - line_width/2.0 );
	temp[2] = slot_dims[2]/2.0 - line_width/2.0;
	outline_ends.add( temp );
	
	temp[1] = -temp[1];
	outline_ends.add( temp );
	
	temp[2] = -temp[2];
	outline_ends.add( temp );
	
	temp[1] = -temp[1];
	outline_ends.add( temp );
	
	# Draw the outline boxes
	loop
		int i = 1
	until
		i > outlines.count()
	begin
		outlines[i] = new line_graphic();
		outlines[i].set_line_width( line_width );
		outlines[i].set_line_color( outline_color );
		outlines[i].add_polygon( outline_ends, false, 1.0, 0.0 );
		outlines[i].redraw();
		i = i + 1;
	end;
	
	# Redraw the "selection" outline box
	sel_box.set_line_width( line_width );
	sel_box.set_line_color( cursor_color );
	sel_box.add_polygon( outline_ends, false, 1.0, 0.0 );
	sel_box.redraw();	
	
	# Add images to the test pic
	loop
		int i = 1
	until
		i > grid_locs.count()
	begin
		test_pic.add_part( images[i], grid_locs[i][1], grid_locs[i][2] );
		i = i + 1;
	end;
	
	# Add outlines to the test pic
	# We do this separately so that the images are the first set of picture parts
	loop
		int i = 1
	until
		i > grid_locs.count()
	begin
		test_pic.add_part( outlines[i], grid_locs[i][1], grid_locs[i][2] );
		i = i + 1;
	end;
	
end;

# --- Main Sequence --- #

# Set some captions
string complete_caption = string_replace( get_lang_item( lang, "Completion Screen Caption" ) );

# Main sequence
if ( prac_cond_array.count() > 0 ) then
	present_instructions( instructions + get_lang_item( lang, "Practice Caption" ) );
	show_trial_sequence( prac_cond_array, PRACTICE_TYPE_PRACTICE );
	
#	show_study();
	#ITI_trial.present();
	
	# Wait
#	if ( retention_interval > 0 ) then
#		trial_refresh_fix( ITI_trial, retention_interval );
#		ITI_trial.present();
#	end;
	
	present_instructions( get_lang_item( lang, "Practice Complete Caption" ) );
	present_instructions( reminder_cap );
else
	present_instructions( instructions );
end;
#show_trial_sequence( cond_array, PRACTICE_TYPE_MAIN );
present_instructions( complete_caption );
