/*     Simple Stepper Motor Control Exaple Code
 *      
 *  by Dejan Nedelkovski, www.HowToMechatronics.com
 *  
 */
// defines pins numbers
const int stepPin = 11; 
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
  
  int _time = 200;
  
  digitalWrite(dirPin,LOW); // Enables the motor to move in a particular direction
  digitalWrite(dirPin2,HIGH); // Enables the motor to move in a particular direction

  
// Makes 200 pulses for making one full cycle rotation
  int length_of_square = 1.7 ;
  int steps = length_of_square*3200;
  for(int x = 0; x < steps; x++) {
    digitalWrite(stepPin,HIGH); 
    digitalWrite(stepPin2,LOW); 
    delayMicroseconds(_time); 
    digitalWrite(stepPin,LOW); 
    delayMicroseconds(_time); 
  }

}
