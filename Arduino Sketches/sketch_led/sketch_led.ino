int redPin = 7;
int greenPin = 6;
int bluePin = 5;

void setup() {
  // put your setup code here, to run once:
  pinMode(redPin, OUTPUT);
  pinMode(greenPin, OUTPUT);
  pinMode(bluePin, OUTPUT);
}

void loop() {
  // put your main code here, to run repeatedly:
  setColor(255, 0, 0); // Red Color
  delay(100);
  setColor(0, 255, 0); // Green Color
  delay(100);
  setColor(0, 0, 255); // Blue Color
  delay(100);
  setColor(255, 255, 255); // White Color
  delay(100);
  setColor(170, 0, 255); // Purple Color
  delay(100);
}

void setColor(int redValue, int greenValue, int blueValue) {
  analogWrite(redPin, redValue);
  analogWrite(greenPin, greenValue);
  analogWrite(bluePin, blueValue);
}
