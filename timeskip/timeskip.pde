import SimpleOpenNI.*;
SimpleOpenNI  context;

// ------------------------
//idiotic circular queue
int CQ_SIZE = 100;
PImage[] ImageQueue; 
int _cq_current = 0;

void cq_setup()
{
  ImageQueue = new PImage[CQ_SIZE];
  
  for (int i = 0; i < CQ_SIZE; i++)
  {
    ImageQueue[i] = createImage(640, 480, RGB);  
  }
}

void _cq_advance_index()
{
  _cq_current++;
  if (_cq_current >= CQ_SIZE)
    _cq_current = 0;
}

int _get_prev_index(int indicies_back)
{
  assert(indicies_back >= 0);
  
  int val = _cq_current - indicies_back; 
  while (val < 0) {
    val += CQ_SIZE;  
  };
  
  return val;
}

void cq_push(PImage next_image)
{
  _cq_advance_index();
  ImageQueue[_cq_current].copy(next_image, 0,0,640,480, 0,0,640,480);
}

PImage cq_get_prev(int indicies_back)
{
  int prevIndex = _get_prev_index(indicies_back);
  println("_cq_current " + _cq_current + " indicies_back " + indicies_back + " getting " + prevIndex);
  
  return ImageQueue[prevIndex];
}

PImage cq_get_now()
{
  return cq_get_prev(0);
}
// ------------------------

void setup_default()
{
  background(200,0,0);
  size(context.depthWidth() + context.rgbWidth() + 10, context.rgbHeight());   
}

Boolean DEBUG = true;

void setup_context()
{
  context = new SimpleOpenNI(this);
  if(context.isInit() == false)
  {
     println("Can't init SimpleOpenNI, maybe the camera is not connected!"); 
     exit();
     return;  
  }
  // enable depthMap generation 
  context.enableDepth();
  // enable camera image generation
  context.enableRGB();
  // enable skeleton generation for all joints
  context.enableUser();
  println("done kinect setup");
}

void setup()
{
  setup_context();
  cq_setup();
  smooth();
 
//  setup_default();
 
 
  background(200,0,0);
  size(context.rgbWidth(), context.rgbHeight()); 
  if (DEBUG)
    size(context.rgbWidth() + context.depthWidth(), context.rgbHeight()); 
    
  size(context.rgbWidth() + context.depthWidth(), context.rgbHeight()*2);
  
}

void draw_default()
{
  // draw depthImageMap
  image(context.depthImage(),0,0);
  
  // draw camera
  image(context.rgbImage(),context.depthWidth() + 10,0);
}


int[] userMap;

PImage lastRGB;

void draw()
{
  // update the kinect
  context.update();
  
  //DEBUG
  scale(0.5);
  
//  draw_default();

 lastRGB = context.rgbImage();
 
 PImage debugUser = createImage(640, 480, RGB);
 debugUser.copy(lastRGB,0,0,640,480,0,0,640,480);


// if we have detected any users
//  if (context.getNumberOfUsers() > 0) { 

    // find out which pixels have users in them
    userMap = context.userMap(); 

    // populate the pixels array
    // from the sketch's current contents

    for (int i = 0; i < userMap.length; i++) { 
      // if the current pixel is on a user
      if (userMap[i] != 0) {
        // make it green
//        pixels[i] = color(0, 255, 0); 
        debugUser.pixels[i] = color(0, 255, 0);
      }
      else
      {
//        debugUser.pixels[i] = color(255, 0, 0);
      }
    }
//    }
    // display the changed pixel array
//    updatePixels(); 

    
  
  PImage prevImage = cq_get_prev(40);
  
  color BORDER_COLOUR = color(0, 100, 220); 
  
  PImage composited = createImage(640, 480, RGB);
  for (int i = 0; i < composited.pixels.length; i++) { 
    if (userMap[i] != 0)
      composited.pixels[i] = prevImage.pixels[i];
    else
      composited.pixels[i] = lastRGB.pixels[i];
      
    //border
    if (i > 0 && i < composited.pixels.length &&
      userMap[i] != userMap[i-1])
      composited.pixels[i] = BORDER_COLOUR;
      
  }
  
  
  image(lastRGB,0,0);
  image(debugUser, context.rgbWidth(),0);
  image(prevImage, 0, context.rgbHeight());
  image(composited, context.rgbWidth(), context.rgbHeight());
  
  
  
  cq_push(lastRGB);

//   if (DEBUG)
//     image(context.userImage(), context.rgbWidth(),0);
}


// -----------------------------------------------------------------
// SimpleOpenNI events

void onNewUser(SimpleOpenNI curContext, int userId)
{
  println("onNewUser - userId: " + userId);
  println("\tstart tracking skeleton");
  
  curContext.startTrackingSkeleton(userId);
}

