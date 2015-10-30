import SimpleOpenNI.*;

SimpleOpenNI  context;

void setup_default()
{
  background(200,0,0);
  size(context.depthWidth() + context.rgbWidth() + 10, context.rgbHeight());   
}

void setup()
{
  context = new SimpleOpenNI(this);
  // enable depthMap generation 
  context.enableDepth();
  // enable camera image generation
  context.enableRGB();
 
  setup_default();
 
  println("done setup");
}

void draw_default()
{
  // draw depthImageMap
  image(context.depthImage(),0,0);
  
  // draw camera
  image(context.rgbImage(),context.depthWidth() + 10,0);
}

void draw()
{
  // update the kinect
  context.update();
  
  draw_default();
}
