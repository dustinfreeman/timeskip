import SimpleOpenNI.*;
SimpleOpenNI  context;

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
  
  smooth();
 
//  setup_default();
 
 
  background(200,0,0);
  size(context.rgbWidth(), context.rgbHeight()); 
  if (DEBUG)
    size(context.rgbWidth() + context.depthWidth(), context.rgbHeight()); 
  
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

    
  image(lastRGB,0,0);
  image(debugUser,context.rgbWidth(),0);

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

