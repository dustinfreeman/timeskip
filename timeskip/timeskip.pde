import SimpleOpenNI.*;
SimpleOpenNI  context;

// idiotic circular queue ------------------------
int CQ_SIZE = 100;
PImage[] CQ_ImageQueue; 
int _cq_current = 0;

void cq_setup()
{
  CQ_ImageQueue = new PImage[CQ_SIZE];
  for (int i = 0; i < CQ_SIZE; i++)
    CQ_ImageQueue[i] = createImage(640, 480, RGB);  
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
  CQ_ImageQueue[_cq_current].copy(next_image, 0,0,640,480, 0,0,640,480);
}

PImage cq_get_prev(int indicies_back)
{
  int prevIndex = _get_prev_index(indicies_back);
//  println("_cq_current " + _cq_current + " indicies_back " + indicies_back + " getting " + prevIndex);
  
  return CQ_ImageQueue[prevIndex];
}

PImage cq_get_now()
{
  return cq_get_prev(0);
}
// end idiotic circular queue------------------------

// spacing queue ------------------------

int SQ_SIZE = 200;
PImage[] SQ_ImageQueue; 

int _sq_push_index = 0;
int _sq_try_push_count = 0;
int _sq_push_delay = 1;

int _sq_get_index = 0;

void sq_setup()
{
  SQ_ImageQueue = new PImage[SQ_SIZE];
  for (int i = 0; i < SQ_SIZE; i++)
    SQ_ImageQueue[i] = createImage(640, 480, RGB);   
}

void _sq_advance_push_index()
{
  _sq_push_index++;
  if (_sq_push_index >= SQ_SIZE)
  {
    //magic halving the effective array; speeding up the timeskip
    for (int i = 0; i < SQ_SIZE/2; i++)
      SQ_ImageQueue[i] = SQ_ImageQueue[2*i];
      
    _sq_push_index = SQ_SIZE/2;
    _sq_push_delay*=2;
    
    println("_sq_push_delay (aka playback rate) is now " + _sq_push_delay);
  }
}

void _sq_push(PImage next_image)
{
  _sq_advance_push_index();
  SQ_ImageQueue[_sq_push_index].copy(next_image, 0,0,640,480, 0,0,640,480);
  
//  println("_sq_push_index " + _sq_push_index);
}

void sq_try_push(PImage next_image)
{
  _sq_try_push_count++;
  if (_sq_try_push_count % _sq_push_delay == 0)
    _sq_push(next_image);     
}

PImage sq_get()
{
  PImage gotImage = SQ_ImageQueue[_sq_get_index];
//  println("sq_get " + _sq_get_index);
  
  _sq_get_index++;
  // if we get from somewhere after the current push index,
  // we're getting from an area that could be playing at a slower framerate than
  // current.
  if (_sq_get_index >= _sq_push_index)
  {
    println("SQ get looped @ " + _sq_get_index);
    _sq_get_index = 0;
  }
  
  return gotImage;
}

// end spacing queue ------------------------

void setup_default()
{
  background(200,0,0);
  size(context.depthWidth() + context.rgbWidth() + 10, context.rgbHeight());   
}

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
  
  // align depth data to image data
  context.alternativeViewPointDepthToImage();
}

void setup()
{
  setup_context();
//  cq_setup();
  sq_setup();
  smooth();
  frameRate(30);
 
//  setup_default();
 
  background(200,0,0);
  size(context.rgbWidth(), context.rgbHeight()); 
    
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
Boolean drawing = false;
void draw()
{
  
  if (drawing)
    println("Fuck! Double draw");
    
  drawing = true;
  
  // update the kinect
  context.update();
  
  //DEBUG
  scale(0.5);
  
//  draw_default();

  lastRGB = context.rgbImage();
// cq_push(lastRGB);
  sq_try_push(lastRGB);
   
 PImage debugUser = createImage(640, 480, RGB);
 debugUser.copy(lastRGB,0,0,640,480,0,0,640,480);

    // find out which pixels have users in them
    userMap = context.userMap(); 

    // populate the pixels array
    // from the sketch's current contents

    for (int i = 0; i < userMap.length; i++) { 
      if (userMap[i] != 0) {
        // make it green
       debugUser.pixels[i] = color(0, 255, 0);
      }
      else
      {
//        debugUser.pixels[i] = color(255, 0, 0);
      }
    }
    
  
//  PImage prevImage = cq_get_prev(40);
  PImage prevImage = sq_get();
  
  // creation of the timeskip composite.
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


  drawing = false;
}


// -----------------------------------------------------------------
// SimpleOpenNI events

void onNewUser(SimpleOpenNI curContext, int userId)
{
  println("onNewUser - userId: " + userId);
  println("\tstart tracking skeleton");
  
  curContext.startTrackingSkeleton(userId);
}

