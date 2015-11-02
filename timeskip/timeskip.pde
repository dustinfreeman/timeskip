import SimpleOpenNI.*;
SimpleOpenNI  context;

Boolean KINECT = true;
Boolean DEV_MODE = false;
Boolean BLUR_MODE = true;

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

color even_blend(color c1, color c2)
{
//  int a = (c1 >> 24) & 0xFF;
  int r1 = ( (c1 >> 16) & 0xFF);  // Faster way of getting red(argb)
  int g1 = ( (c1 >> 8) & 0xFF );  // Faster way of getting green(argb)
  int b1 = ( c1 & 0xFF        );  // Faster way of getting blue(argb)
  
  int r2 = ( (c2 >> 16) & 0xFF);  // Faster way of getting red(argb)
  int g2 = ( (c2 >> 8) & 0xFF );  // Faster way of getting green(argb)
  int b2 = ( c2 & 0xFF        );  // Faster way of getting blue(argb)
  
//  println(" c1 " + r1 + "," + g1 + "," + b1 + " " +
//    " c2 " + r2 + "," + g2 + "," + b2 + " " +
//    " even_blend " + (r1+r2)/2 + "," + (g1+g2)/2 + "," + (b1+b2)/2
//    );
  
  return color((r1+r2)/2, (g1+g2)/2, (b1+b2)/2); 
}

// spacing queue ------------------------

int SQ_SIZE = 200;
PImage[] SQ_ImageQueue; 
int[] SQ_debugIntQueue;

int _sq_push_index = 0;
int _sq_try_push_count = 0;
int _sq_push_delay = 1;

int _sq_get_index = 0;

void sq_setup()
{
  if (!KINECT)
    SQ_SIZE = 16;
  
  SQ_debugIntQueue = new int[SQ_SIZE];
  SQ_ImageQueue = new PImage[SQ_SIZE];
  for (int i = 0; i < SQ_SIZE; i++) 
  {
    SQ_ImageQueue[i] = createImage(640, 480, RGB); 
    SQ_debugIntQueue[i] = -1;
  }  
}

void _sq_advance_push_index()
{
  _sq_push_index++;
  if (_sq_push_index >= SQ_SIZE)
  {
    //magic halving the effective array; speeding up the timeskip
//    print("Halve: ");
    for (int i = 0; i < SQ_SIZE/2; i++)
    {
      if (BLUR_MODE)
      {
        //it would be nice to use BLEND, but this requires the image to have an alpha
        // channel, which it does not.
        // SQ_ImageQueue[i].blend(SQ_ImageQueue[2*i], 0,0,640,480, 0,0,640,480, BLEND);
        for (int p = 0; p < SQ_ImageQueue[i].width*SQ_ImageQueue[i].height; p++)
        {
          color blended = even_blend(SQ_ImageQueue[2*i].pixels[p], 
                                        SQ_ImageQueue[2*i+1].pixels[p]);
                                        
//          if (p == (320*480 + 320))
//          {
//            println("blended, SQ_ImageQueue[2*i].pixels[p], SQ_ImageQueue[2*i+1].pixels[p] \n" 
//            + blended + "," + SQ_ImageQueue[2*i].pixels[p] + "," + SQ_ImageQueue[2*i+1].pixels[p]); 
//          }
            
          SQ_ImageQueue[i].pixels[p] = blended;
        }
         
      }
      else
      {
        SQ_ImageQueue[i].copy(SQ_ImageQueue[2*i], 0,0,640,480, 0,0,640,480); 
      }
      SQ_debugIntQueue[i] = SQ_debugIntQueue[2*i]; 
//      print(i + ":" + SQ_debugIntQueue[i] + " ");
    }
//    println();
  
    _sq_push_index = SQ_SIZE/2;
    _sq_push_delay*=2;
    
    println("_sq_push_delay (aka playback rate) is now " + _sq_push_delay);
  }
}

void _sq_push(PImage next_image)
{
  if (KINECT)
    SQ_ImageQueue[_sq_push_index].copy(next_image, 0,0,640,480, 0,0,640,480);
  SQ_debugIntQueue[_sq_push_index] = _sq_try_push_count;
  
  if (!KINECT)
    println("_sq_push_index " + _sq_push_index + " " + _sq_try_push_count);
  
  _sq_advance_push_index();
}

//have to do it this way because I think PIImage keeps data at a low int res
int[] _sq_pre_push_r = new int[640*480]; 
int[] _sq_pre_push_g = new int[640*480]; 
int[] _sq_pre_push_b = new int[640*480]; 

void sq_try_push(PImage next_image)
{
  _sq_try_push_count++;
  //blend it into the pre-push frame
  for (int p = 0; p < 640*480; p++)
  {
    _sq_pre_push_r[p] += (next_image.pixels[p] >> 16) & 0xFF;
    _sq_pre_push_g[p] += (next_image.pixels[p] >> 8) & 0xFF;
    _sq_pre_push_b[p] += next_image.pixels[p] & 0xFF;
  }
  if (_sq_try_push_count % _sq_push_delay == 0)
  {
    PImage push_image = createImage(640, 480, RGB);
    for (int p = 0; p < push_image.width*push_image.height; p++)
    {
      int p_value = (_sq_pre_push_r[p]/_sq_push_delay) << 16 |
                    (_sq_pre_push_g[p]/_sq_push_delay) << 8  |
                    (_sq_pre_push_b[p]/_sq_push_delay);
      push_image.pixels[p] = p_value;
    }
    _sq_push(push_image);
    
    //clear it out
    _sq_pre_push_r = new int[640*480]; 
    _sq_pre_push_g = new int[640*480]; 
    _sq_pre_push_b = new int[640*480]; 
  }
  
  if (!KINECT)
    println("sq_try_push " + _sq_try_push_count);  
}

PImage sq_get_at_index(int get_at_index)
{
  PImage gotImage = SQ_ImageQueue[get_at_index];
  int getValue = SQ_debugIntQueue[get_at_index];
  if (!KINECT)
    println("sq_get index:" + get_at_index + "\tvalue:" + getValue);
    
  return gotImage;
}

PImage sq_get()
{
  PImage gotImage = sq_get_at_index(_sq_get_index);
  
  _sq_get_index++;
  // if we get from somewhere after the current push index,
  // we're getting from an area that could be playing at a slower framerate than
  // current.
  if (_sq_get_index >= _sq_push_index)
  {
//    println("SQ get looped @ " + _sq_get_index);
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
  if (!KINECT)
    return;
  
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
  if (!KINECT)
    frameRate(1);
 
//  setup_default();

  background(200,0,0);
  size(640,480); 
}

void draw_default()
{
  // draw depthImageMap
  image(context.depthImage(),0,0);
  
  // draw camera
  image(context.rgbImage(),context.depthWidth() + 10,0);
}


int[] userMap;

PImage lastRGB = createImage(640, 480, RGB);
Boolean drawing = false;
void draw()
{
  
  if (drawing)
    println("Fuck! Double draw");
    
  drawing = true;
  
  // update the kinect
  if (KINECT)
    context.update();
  
  if (DEV_MODE)
    scale(0.5);
  else
    scale(1);

  if (KINECT)
  {
    lastRGB = context.rgbImage();
  }
// cq_push(lastRGB);
  sq_try_push(lastRGB);
   
  PImage debugUser = createImage(640, 480, RGB);
  if (DEV_MODE)
    debugUser.copy(lastRGB,0,0,640,480,0,0,640,480);

    // find out which pixels have users in them
  if (KINECT)
  {
    userMap = context.userMap(); 

    // populate the pixels array
    // from the sketch's current contents
    
    if (DEV_MODE)
    {
      for (int i = 0; i < userMap.length; i++) { 
        if (userMap[i] != 0)
          debugUser.pixels[i] = color(0, 255, 0);
      }
    }
  }
  
//  PImage prevImage = cq_get_prev(40);
  PImage prevImage; 
  if (forceGetIndex >= 0)
    prevImage = sq_get_at_index(forceGetIndex);
  else
    prevImage = sq_get();
  
  // creation of the timeskip composite.
  color BORDER_COLOUR = color(0, 100, 220); 
  PImage composited = createImage(640, 480, RGB);
  for (int i = 0; i < composited.pixels.length; i++) { 
    if (!KINECT)
      break;
    
    if (userMap[i] != 0)
      composited.pixels[i] = prevImage.pixels[i];
    else
      composited.pixels[i] = lastRGB.pixels[i];
      
    //border
    if (i > 0 && i < composited.pixels.length && userMap[i] != userMap[i-1])
      composited.pixels[i] = BORDER_COLOUR;
      
  }
  
  if (DEV_MODE)
  {
    image(lastRGB,0,0);
    image(debugUser, 640,0);
    image(prevImage, 0, 480);
    image(composited, 640,480);
  }
  else
  {
    image(composited, 0, 0);
  }

  drawing = false;
}

int forceGetIndex = -1;
void keyPressed()
{
  if (keyCode == LEFT)
  {
    forceGetIndex--;
  }
  if (keyCode == RIGHT)
  {
    if (forceGetIndex < SQ_SIZE - 1)
      forceGetIndex++;
  }
  println("forceGetIndex: " + forceGetIndex);
  
  if (keyCode == BACKSPACE)
    DEV_MODE = !DEV_MODE;
}

// -----------------------------------------------------------------
// SimpleOpenNI events

void onNewUser(SimpleOpenNI curContext, int userId)
{
  println("onNewUser - userId: " + userId);
  println("\tstart tracking skeleton");
  
  curContext.startTrackingSkeleton(userId);
}

