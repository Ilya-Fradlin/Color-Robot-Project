/*
--------------------
ColoRobot
--------------------
*/

#include <Servo.h>

/***************************************************************************
 DECLARATIONS AND GLOBALS
 ***************************************************************************/
// ----- constants
#define PI 3.1415926535897932384626433832795
#define RAD_TO_DEG 57.295779513082320876798154814105

// ----- Bit set/clear/check/toggle macros
#define SET(x,y) (x |=(1<<y))
#define CLR(x,y) (x &= (~(1<<y)))

// ----- motor definitions
#define STEPS_PER_REV 200*8 				 //steps for one motor shaft revolution
#define STEP_X 2                     //arduino ports
#define STEP_Y 3
#define STEP_Z 4
#define DIRECTION_X 5
#define DIRECTION_Y 6
#define DIRECTION_Z 7

#define CW false						//opposite turn direction
#define CCW true						//default turn direction

#define FORWARD true					//travel direction

long
PULSE_WIDTH = 2,                    //easydriver step pulse-width (uS)
DELAY = 2000;                       //delay (2-uS) between motor steps (controls speed)

bool direction = FORWARD;				//default travel direction
byte pattern;							//used for bitwise motor control

// pen-lift definitions ------------------
#define SERVO_STEP 1
#define PEN_UP_DEGREE 164
#define BLACK_LOWER_DEGREE 62
#define BLUE_LOWER_DEGREE 66
#define RED_LOWER_DEGREE 55
#define GREEN_LOWER_DEGREE 65
enum pen_color {black, blue, red, green};     //define color positions
pen_color current_color = black;
int PEN_DOWN_DEGREE = BLACK_LOWER_DEGREE;
int pen = 9;							//pen-lift servo
int pen_position = 0;
bool pen_is_down = false;

Servo myservo;


// gcode buffer definitions --------------
#define MAX_LENGTH 128			//maximum message length
char message[MAX_LENGTH];		//Command string stored here
int index=0;							  //character position in message[]
char character;							//an actual character

// flow control
#define XON 0x11						//resume transmission (DEC 17)
#define XOFF 0x13						//pause transmission (DEC 19)

// plotter definitions -------------------
float CWR_cal;					    //holds trial CWR value when calibrating
bool CWR_flag = false;			//indicates use "trial CWR value"
#define CWR 3.1100					//CWR value for the robot (calculated = 3.0769 )
#define BAUD 9600						//serial connection speed to Arduino

bool SCALE_flag = false;			//indicates "use custom SCALE"
float SCALE_mult = 1;					//0.5=50%; 1=100%; 2=200%; etc
float SCALE_custom;						//holds custom SCALE value
#define SCALE 7.8353				  //output scaled to 1mm per step which is approx 100%


/***************************************************************************
 SETUP
 ***************************************************************************/
void setup()
{
  //-------------------------------
	// delay to let the entire hardware time to stabilize
	//-------------------------------
  delayMicroseconds(DELAY);

	//-------------------------------
	// initialise motor1-x (left-wheel)
	//-------------------------------
  pinMode(STEP_X, OUTPUT);
  pinMode(DIRECTION_X, OUTPUT);
  digitalWrite(DIRECTION_X, CW);
  delayMicroseconds(PULSE_WIDTH);
  digitalWrite(STEP_X, LOW);

	//-------------------------------
	// initialise motor2-y(right-wheel)
	//-------------------------------
  pinMode(STEP_Y, OUTPUT);
  pinMode(DIRECTION_Y, OUTPUT);
  digitalWrite(DIRECTION_Y, CW);
  delayMicroseconds(PULSE_WIDTH);
  digitalWrite(STEP_Y, LOW);

  //-------------------------------
	// initialise motor3-z (color-switching)
	//-------------------------------
  pinMode(STEP_Z, OUTPUT);
  pinMode(DIRECTION_Z, OUTPUT);
  digitalWrite(DIRECTION_Z, CW);
  delayMicroseconds(PULSE_WIDTH);
  digitalWrite(STEP_Z, LOW);

  //-------------------------------
	// delay to let the entire hardware time to stabilize
	//-------------------------------
  delayMicroseconds(DELAY);

	//-------------------------------
	// pen-lift
	//-------------------------------
	pinMode(pen, OUTPUT);
  delayMicroseconds(DELAY);
  myservo.attach(pen);
  delayMicroseconds(DELAY);
  for (pen_position = myservo.read(); pen_position <= PEN_UP_DEGREE; pen_position += SERVO_STEP) {
    myservo.write(pen_position);
    delay(20);
  }
  delayMicroseconds(DELAY);

	//--------------------------------
	// plotter setup
	//--------------------------------
	Serial.begin(BAUD);		//open serial link
	menu();								//display commands

  //-------------------------------
  // delay to let the entire hardware time to stabilize
  //-------------------------------
  delay(100);
}

/***************************************************************************
 MAIN LOOP
 ***************************************************************************/
void loop()
{
	if (Serial.available()){			     	//check serial input for data
		character = Serial.read();			  //get character
		if (index < MAX_LENGTH-1){
			message[index++] = character;	 //store it
			Serial.print(character);		   //display it
		}else{
			Serial.println("");
			Serial.print(F("Error: buffer overflow"));
		}
		if (character=='\n'){		    //Command lines should end with \r\n
		    message[index]=0;  		  //insert end-of-string char
			Serial.print(XOFF);			  //tell terminal to stop sending
			Serial.print(": ");		    //screen formatting

			process_commands();

			index=0;					      //prepare for next message
			Serial.print(XON);			//tell terminal to resume sending
			Serial.print(": ");			//screen formatting
		}
	}
}

/***************************************************************************
 PROCESS_COMMANDS
 All of the "Processing" is done here.

The move commands generated from the always have a Y-coordinate if there is an X-coordinate which
means the following simplifications are valid:
 G00: pen-up. Use X,Y (if any)
 G01: pen-down. Use X,Y (if any)
 ***************************************************************************/
void process_commands(){
	float x2, y2 = -1;					      //temp X,Y values

	//-------------------------------------------------
	int gcode = get_value('G', -1);		//Get G code
	//-------------------------------------------------
	switch (gcode){
		case 0:{ 						            //Move with pen-up
			pen_up();
			x2 = get_value('X', -1);
			y2 = get_value('Y', -1);
			if ((x2 >= 0) & (y2 >= 0)){
				move_to(x2, y2);
			}
			break;
		}
		case 1:{						           //Move with pen-down
			pen_down();
			x2 = get_value('X', -1);
			y2 = get_value('Y', -1);
			if ((x2 >= 0) & (y2 >= 0)){
				move_to(x2, y2);
			}
			break;
		}
		case 2:{					          	//Move with pen-down
			pen_down();
			x2 = get_value('X', -1);
			y2 = get_value('Y', -1);
			if ((x2 >= 0) & (y2 >= 0)){
				move_to(x2, y2);
			}
			break;
		}
		case 3:{					          	//Move with pen-down
			pen_down();
			x2 = get_value('X', -1);
			y2 = get_value('Y', -1);
			if ((x2 >= 0) & (y2 >= 0)){
				move_to(x2, y2);
			}
			break;
		}
		default:{
			break;
		}
	}

	//--------------------------------------------------
	int mcode = get_value('M', -1);		//Get M code
	//--------------------------------------------------
	switch (mcode){
		case 100:{						//Display menu
			menu();
			break;
		}
		default:{
			break;
		}
	}

	//--------------------------------------------------
	int tcode = get_value('T', -1);		//Get T code
	//--------------------------------------------------
	switch (tcode){						//test patterns
		case 100:{
			CWR_cal = get_value('C', -1);
			if (CWR_cal > 0){
				CWR_flag = true;
				Serial.print("CWR now ");
				Serial.println(CWR_cal,4);

			} else {
				Serial.println("Invalid CWR ratio ... try again");
			}
			break;
		}
		case 101:{
			float SCALE_mult = get_value('S', -1);
			if (SCALE_mult > 0){
				SCALE_flag = true;
				Serial.print("SIZE now ");
				Serial.print(SCALE_mult*100);
				Serial.println("%");
				SCALE_custom = SCALE*SCALE_mult;
			} else {
				Serial.println("Invalid SIZE multiplier ... try again");
			}
			break;
		}
		case 102:{
			square();					   //plot square
			break;
		}
		case 103:{ 						//plot square, diagonals, circle
			test_pattern();
			break;
		}
		case 104:{ 						//raise pen
			pen_up();
			break;
		}
		case 105:{ 						//lower pen
			pen_down();
			break;
		}
    case 106:{ 						//change lower servo limit
      int new_limit = get_value('L', -1);
      if (new_limit > 0){
        Serial.print("PEN_DOWN_DEGREE is now ");
        Serial.print(new_limit);
        PEN_DOWN_DEGREE = new_limit;
      } else {
        Serial.println("Invalid PEN_DOWN_DEGREE ... try again");
      }
      break;
    }
    case 107:{ 				//Turn Around the same spot
      int number_of_spins = get_value('R', -1);
      if (number_of_spins > 0){
        Serial.print("number of spins required is ");
        Serial.print(number_of_spins);
        rotate_full_spins(number_of_spins);
      } else {
        Serial.println("Invalid Number of turns ... try again");
      }
      break;
    }
    default:{
      break;
    }
	}

  //--------------------------------------------------
  int ccode = get_value('C', -1);		//Get C code
  //--------------------------------------------------
  switch (ccode){
    case 101:{						//turn the color wheel a quarter of a circle
      switch_color(1);
      for (int i = 0; i < 1; i++) {
        adjust_pen_down_limit();
      }
      break;
    }
    case 102:{						//turn the color wheel half of a circle
      switch_color(2);
      for (int i = 0; i < 2; i++) {
        adjust_pen_down_limit();
      }
      break;
    }
    case 103:{						//turn the color wheel three quarters of a circle
      switch_color(3);
      for (int i = 0; i < 3; i++) {
        adjust_pen_down_limit();
      }
      break;
    }
    case 104:{						//turn the color wheel a full circle
      switch_color(4);
      for (int i = 0; i < 4; i++) {
        adjust_pen_down_limit();
      }
      break;
    }
    default:{
      break;
    }
  }
}

/***************************************************************************
 GET_VALUE
 Looks for a specific gcode and returns the float that immediately follows.
 It assumes that there is a single ' ' between values.
 If the gcode is not found then the original value is returned.
 ***************************************************************************/
float get_value(char gcode, float val){
	char *ptr=message;

	while ((ptr>=message) && (ptr<(message+MAX_LENGTH))){	//is pointer valid?
		if (*ptr==gcode){
			return atof(ptr+1);
		}
		ptr=strchr(ptr,' ')+1;	//caution: ptr==NULL if ' ' not found
	}

	return val;
}

/***************************************************************************
 MENU
 This interpreter recognizes the following Inkscape g-codes:
 The undefined code M100 is used to access the Menu.
 The undefined code T100 is used to print a Test_pattern.
 The Arduino F() macro is used to conserve RAM.
 ***************************************************************************/
void menu() {
	Serial.println(F("------------------------------------------------------"));
	Serial.println(F("                INKSCAPE COMMANDS"));
	Serial.println(F("------------------------------------------------------"));
	Serial.println(F("G00 [X##] [Y##]........move (linear with pen-up"));
	Serial.println(F("G01 [X##] [Y##]........move (linear with pen-down"));
	Serial.println(F("G02 [X##] [Y##]........move (circular with pen-down)"));
	Serial.println(F("G03 [X##] [Y##]........move (circular with pen-down)"));
	Serial.println(F("M100...................this menu"));
	Serial.println(F("T100 C##.##............custom CWR"));
	Serial.println(F("T101 S##.##............custom SIZE ... 1=100%"));
	Serial.println(F("T102...................draw a square"));
	Serial.println(F("T103...................draw a test pattern"));
	Serial.println(F("T104...................pen up"));
	Serial.println(F("T105...................pen down"));
  Serial.println(F("C100 A##............... Switch the Color"));
  Serial.println(F("T106 [L##].............PEN_DOWN_DEGREE "));
  Serial.println(F("T107 [R##].............Turn Around the same spot "));
	Serial.println(F("------------------------------------------------------"));
}

/***************************************************************************
 MOVE_TO
 Moves robot to next X-Y co-ordinate.  Calculates the distance (steps) and
 a bearing (radians) from its current co-ordinate. The robot always aligns
 itself with the new bearing before moving.
 ***************************************************************************/
void move_to(float x2, float y2){

	//----------------------------------------------------------
	// static values (contents remain between function calls)
	//----------------------------------------------------------
	static float x1, y1 = 0;			//intial co-ordinates
	static float old_bearing = 0;		//current robot bearing from 3 o'clock

	//----------------------------
	// calculate distance (steps)
	//----------------------------
	float dx = x2 - x1;
	float dy = y2 - y1;
	float distance = sqrt(dx*dx + dy*dy);		//steps (pythagoras)

  //----------------------------------
	// calculate true bearing (radians)
 	//----------------------------------
 	int quadrant;
 	float new_bearing;							//new bearing

 	if ((dx==0) & (dy==0)){quadrant = 0;}		//no change
 	if ((dx>0) & (dy>=0)){quadrant = 1;}
 	if ((dx<=0) & (dy>0)){quadrant = 2;}
 	if ((dx<0) & (dy<=0)){quadrant = 3;}
 	if ((dx>=0) & (dy<0)){quadrant = 4;}
    switch (quadrant){
    	case 0: {new_bearing = 0; break;}
    	case 1: {new_bearing = 0 + asin(dy/distance); break;}
    	case 2: {new_bearing = PI/2 + asin(-dx/distance); break;}
    	case 3: {new_bearing = PI + asin(-dy/distance); break;}
    	case 4: {new_bearing = 2*PI - asin(-dy/distance); break;}
    	default: {break;}
    }

  //----------------------------------------------------------
  // align robot with next bearing.
  //----------------------------------------------------------
 	if (new_bearing < old_bearing){
 		rotate(old_bearing - new_bearing, CW);
 	} else {
 		rotate(new_bearing - old_bearing, CCW);
 	}

 	//------------------------
	// move robot along axis
	//------------------------
	move(distance);								//move the robot

	//------------------------
	// update the static values
	//------------------------
	x1 = x2;
	y1 = y2;
	old_bearing = new_bearing;
}

/***************************************************************************
 ROTATE
 Align robot with bearing.
 Note ... since the motors are both inwards pointing the wheels require
 the same patterns if they are to rotate in opposite directions.
 ***************************************************************************/
void rotate(float angle, bool turn_ccw){

	//--------------------
	// initialise
	//--------------------
 	int step = 0;								//pattern counter
 	int steps;									//number of motor steps
  byte pattern = PORTD;

 	//--------------------
	//take smallest turn
	//--------------------
  	if (angle > PI){				//is the interior angle smaller?
 		angle = 2*PI - angle;
 		turn_ccw = !turn_ccw;
 	}

	if (angle > PI/2){				//can we get there faster using reverse?
		angle = PI - angle;
		turn_ccw = !turn_ccw;
		direction = !direction;
	}

  // ----- set motor directions
  /*
     Change CCW to CW if the robot moves in the wrong direction
  */
  turn_ccw ? SET(pattern, DIRECTION_X) : CLR(pattern, DIRECTION_X);
  turn_ccw ? SET(pattern, DIRECTION_Y) : CLR(pattern, DIRECTION_Y);
  PORTD = pattern;
  delayMicroseconds(PULSE_WIDTH);     //wait for direction lines to stabilise

  // ----- calculate steps amount required
  /*
     The calculation is based on the CWR constant, whether its a test or execution
  */
	if (CWR_flag){
		steps = abs((int)(angle*RAD_TO_DEG*STEPS_PER_REV/360*CWR_cal));
	} else {
		steps = abs((int)(angle*RAD_TO_DEG*STEPS_PER_REV/360*CWR));
	}


  //-------------------------------------
 	// raise the pen for the spin. (if its down)
 	//-------------------------------------
  if (pen_is_down){
    int pen_pistion_before_rotation = myservo.read();
    pen_pistion_before_rotation += 25;
    myservo.write(pen_pistion_before_rotation);
    delay(60);
  }
	//-------------------------------------
 	// rotate the robot a specific angle
 	//-------------------------------------
	while (steps-- > 0){
    SET(pattern, STEP_X);
    SET(pattern, STEP_Y);
    PORTD = pattern;
    delayMicroseconds(PULSE_WIDTH);  //mandatory delay

    // ----- create trailing-edge of step-pulse(s)
    pattern = CLR(pattern, STEP_X);
    pattern = CLR(pattern, STEP_Y);
    PORTD = pattern;

  	//allow rotor time to move to next step and determines plotting speed
    delayMicroseconds(DELAY);
  }

  //-------------------------------------
  // lower back the pen (if it was down)
  //-------------------------------------
  if (pen_is_down){
    for (pen_position = myservo.read(); pen_position >= PEN_DOWN_DEGREE; pen_position -= 5) {
      myservo.write(pen_position);
      delay(25);
    }
  }
}

/***************************************************************************
 MOVE
 Move robot along bearing
 Note ... since the motors are both inwards pointing the wheels require
 counter_rotating patterns if they are to rotate in the same direction.
 ***************************************************************************/
void move(float distance){

	//------------------
	// initialise
	//------------------
	int step = 0;
	int steps;
  byte pattern = PORTD;

  // ----- set motor directions
  /*
     Change CCW to CW if the robot moves in the wrong direction
  */
  direction ? SET(pattern, DIRECTION_X) : CLR(pattern, DIRECTION_X);
  direction ? CLR(pattern, DIRECTION_Y): SET(pattern, DIRECTION_Y);
  PORTD = pattern;
  delayMicroseconds(PULSE_WIDTH);     //wait for direction lines to stabilise

  // ----- calculate steps amount required
  /*
     The calculation is based on the CWR constant, whether its a test or execution
  */
	if (SCALE_flag){
		steps = (int)(distance*SCALE_custom);	//use custom scale
	} else {
		steps = (int)(distance*SCALE);			//default
	}

	//----------------------------------------
 	//move the robot to the next co-ordinate
 	//-----------------------------------------
	while (steps-- > 0){
    SET(pattern, STEP_X);
    SET(pattern, STEP_Y);
    PORTD = pattern;
    delayMicroseconds(PULSE_WIDTH);  //mandatory delay

    // ----- create trailing-edge of step-pulse(s)
    pattern = CLR(pattern, STEP_X);
    pattern = CLR(pattern, STEP_Y);
    PORTD = pattern;

    //allow rotor time to move to next step and determines plotting speed
    delayMicroseconds(DELAY);
	}
}

/***************************************************************************
 SQUARE
 Adjust CWR until square is a perfect closed loop. If CWR is too small the
 square will be open at one corner. If the CWR is too big then the start
 point will protrude.
 ***************************************************************************/
void square(){

	// square ------------
	pen_up();
	move_to(37.656509, 210.457146);
	pen_down();
	move_to(173.929525, 210.457146);
	move_to(173.929525, 79.022220);
	move_to(37.656509, 79.022220);
	move_to(37.656509, 210.457146);
	pen_up();

	// home --------------
	move_to(0.0000, 0.0000);
}

/***************************************************************************
 TEST_PATTERN
 ***************************************************************************/
void test_pattern(){

	// circle ------------
	pen_up();
	move_to(136.738441, 145.187821);
	pen_down();
	move_to(134.380298, 133.732203);
	move_to(127.595170, 123.920361);
	move_to(117.521703, 117.417222);
	move_to(105.521361, 115.111091);
	move_to(93.521020, 117.417222);
	move_to(83.447553, 123.920361);
	move_to(76.662425, 133.732203);
	move_to(74.304282, 145.187821);
	move_to(76.662425, 156.643438);
	move_to(83.447553, 166.455281);
	move_to(93.521020, 172.958420);
	move_to(105.521361, 175.264551);
	move_to(117.521703, 172.958420);
	move_to(127.595170, 166.455281);
	move_to(134.380298, 156.643438);
	move_to(136.738441, 145.187821);
	move_to(136.738441, 145.187821);
	pen_up();

  // home --------------
  move_to(0.0000, 0.0000);

  // switch Color  (from Black to Blue)
  switch_color(1);
  for (int i = 0; i < 1; i++) {
    adjust_pen_down_limit();
  }

	// back-slash -----------
	pen_up();
	move_to(37.813081, 210.330315);

	pen_down();
	move_to(174.084903, 79.190066);
	pen_up();

  // home --------------
  move_to(0.0000, 0.0000);

  // switch Color  (from Blue to Red)
  switch_color(1);
  for (int i = 0; i < 1; i++) {
    adjust_pen_down_limit();
  }

	// slash -------------
	pen_up();
	move_to(37.527994, 79.190066);
	pen_down();
	move_to(173.799816, 210.330315);
	pen_up();

  // home --------------
	move_to(0.0000, 0.0000);

  // switch Color  (from Red to Green)
  switch_color(1);
  for (int i = 0; i < 1; i++) {
    adjust_pen_down_limit();
  }

	// square ------------
	pen_up();
	move_to(37.656509, 210.457146);
	pen_down();
	move_to(173.929525, 210.457146);
	move_to(173.929525, 79.022220);
	move_to(37.656509, 79.022220);
	move_to(37.656509, 210.457146);
	pen_up();

	// home --------------
	move_to(0.0000, 0.0000);

  // switch Color back to initial position (from Green to Black)
  switch_color(1);
  for (int i = 0; i < 1; i++) {
    adjust_pen_down_limit();
  }
}

/***************************************************************************
 PEN_UP
 Raise the pen
 ***************************************************************************/
void pen_up(){
  pen_is_down = false;
  if (myservo.read() >= PEN_UP_DEGREE) {
    return;
  }
  for (pen_position = myservo.read(); pen_position <= PEN_UP_DEGREE; pen_position += SERVO_STEP) {
    myservo.write(pen_position);
    delay(20);
  }
}

/***************************************************************************
 PEN_DOWN
 Lower the pen
 ***************************************************************************/
void pen_down(){
  pen_is_down = true;
  if (myservo.read() <= PEN_DOWN_DEGREE) {
    return;
  }
  for (pen_position = myservo.read(); pen_position >= PEN_DOWN_DEGREE; pen_position -= SERVO_STEP) {
    myservo.write(pen_position);
    delay(20);
  }
}

/***************************************************************************
 Switch the color by the amount of steps given.
 ***************************************************************************/
void switch_color(int turns){
  pen_up();
  int steps_required = 12 * turns;
  for (int upper_motor_step = 0; upper_motor_step < steps_required; upper_motor_step++) {
    digitalWrite(STEP_Z, HIGH);
    delay(10);
    digitalWrite(STEP_Z, LOW);
    delay(100);
  }
}

/***************************************************************************
 Rotate on the same spot the number of rounds requested.
 ***************************************************************************/
void rotate_full_spins(int number_of_spins){

	//--------------------
	// initialise
	//--------------------
 	int step = 0;								//pattern counter
 	int steps;									//number of motor steps
  byte pattern = PORTD;

  // ----- set motor directions
  SET(pattern, DIRECTION_X);
  SET(pattern, DIRECTION_Y);
  PORTD = pattern;
  delayMicroseconds(PULSE_WIDTH);     //wait for direction lines to stabilise

  // ----- calculate steps amount required
  /*
     The calculation is based on the CWR constant, whether its a test or execution
  */
	if (CWR_flag){
		steps = abs((int)(2*PI*number_of_spins*RAD_TO_DEG*STEPS_PER_REV/360*CWR_cal));
	} else {
		steps = abs((int)(2*PI*number_of_spins*RAD_TO_DEG*STEPS_PER_REV/360*CWR));
	}

	//-------------------------------------
 	// rotate the robot a specific angle
 	//-------------------------------------
	while (steps-- > 0){
    SET(pattern, STEP_X);
    SET(pattern, STEP_Y);
    PORTD = pattern;
    delayMicroseconds(PULSE_WIDTH);  //mandatory delay

    // ----- create trailing-edge of step-pulse(s)
    pattern = CLR(pattern, STEP_X);
    pattern = CLR(pattern, STEP_Y);
    PORTD = pattern;

  	//allow rotor time to move to next step and determines plotting speed
    delayMicroseconds(DELAY);
  }
}

void adjust_pen_down_limit(){
  switch(current_color){
    case black:{           //next color in line is blue
      current_color = blue;
      PEN_DOWN_DEGREE = BLUE_LOWER_DEGREE;
      break;
    }
    case blue:{						//next color in line is red
      current_color = red;
      PEN_DOWN_DEGREE = RED_LOWER_DEGREE;
      break;
    }
    case red:{						//next color in line is green
      current_color = green;
      PEN_DOWN_DEGREE = GREEN_LOWER_DEGREE;
      break;
    }
    case green:{						//next color in line is black (cyclic order)
      current_color = black;
      PEN_DOWN_DEGREE = BLACK_LOWER_DEGREE;
      break;
    }
    default:{
      break;
    }
  }
}
