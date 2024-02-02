# Assembly-Image-Matcher
MIPS assembly program that takes a small and a big image and looks for an instance of the small one in the big one

## What it does
Allows the user to give a 512x256 image (for example an image of "Where's Waldo?") and another 8x8 image (for example the face of Waldo).  The program will match the small image with every location of the big image and find where they match best.  It will then highlight the corresponding 8x8 region in green and find Waldo!

## Optimized speed
This program is implemented in a cache-friendly way.  That means that the information needed to be stored in short term memory will conflict as less as possible and we will get Cache hit rates of about 95%, whether we are using Direct, K-way associative, or Full-way associative cache mapping.  Finished among the top 10% best optimized submissions in my 232 students class.
