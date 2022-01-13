/*     Simple Stepper Motor Control Exaple Code
 *      
 *  by Dejan Nedelkovski, www.HowToMechatronics.com
 *  
 */
// defines pins numbers
const int stepPin = 2; 
const int dirPin = 12; 
const int stepPin2 = 3; 
const int dirPin2 = 4; 
 
void setup() {
  // Sets the two pins as Outputs
  pinMode(stepPin,OUTPUT); 
  pinMode(dirPin,OUTPUT);
  pinMode(stepPin2,OUTPUT); 
  pinMode(dirPin2,OUTPUT);
}
void loop() {
  
  int _time = 10;
  
  digitalWrite(dirPin,LOW); // Enables the motor to move in a particular direction
  digitalWrite(dirPin2,HIGH); // Enables the motor to move in a particular direction

  
// Makes 200 pulses for making one full cycle rotation
  int length_of_square = 1 ;
  int steps = 200;//length_of_square*3200;
  for(int x = 0; x < steps; x++) {
    digitalWrite(stepPin,HIGH); 
    digitalWrite(stepPin2,HIGH); 
    delay(_time); 
    digitalWrite(stepPin,LOW); 
    digitalWrite(stepPin2,LOW);    
    delay(_time); 
  }
  delay(5000);

  
// delay(1000); // One second delay
//  digitalWrite(dirPin,LOW); //Changes the rotations direction
//  digitalWrite(dirPin2,HIGH); //Changes the rotations direction

//  digitalWrite(dirPin2,LOW); // Enables the motor to move in a particular direction
//  // make the 90 degree turn
//  int steps_to_turn = 610;
//  for(int x = 0; x < steps_to_turn ; x++) {
//    digitalWrite(stepPin,HIGH); 
//    digitalWrite(stepPin2,HIGH); 
//    delayMicroseconds(_time); 
//    digitalWrite(stepPin,LOW); 
//    digitalWrite(stepPin2,LOW);    
//    delayMicroseconds(_time);
//  }
//  delay(1000);
}
