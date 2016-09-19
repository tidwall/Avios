# Avios

Realtime H264 decoding library for iOS.

This is a very low level component that is intended to process raw [H264]() frames for realtime video playback or processing.

## Typical usage

1. Create an `H264Decoder`
2. Decode an H264 frame to an `AviosImage`. The `AviosImage` is the rendered picture. This is a shared buffer in main memory.
3. Copy the main memory buffer to GPU memory. You can also optionally copy the data to a some other context such as a `UIImage`. Or you can try to wrap a `CGContext` around the shared memory. I've tried a few different things but found that the most efficient and stable way is to use the GPU for displaying the picture. I suggest trying [GPUImage](https://github.com/BradLarson/GPUImage) to help with rendering.

Step 2 and 3 are then repeated over and over again to render and display the video. The framerate and syncing is entirely up to you to manage.

## H264 Streams

There are many H264 video stream formats such as RTP and AnnexB. 

It is your responsibility to parse the stream and extract the frames. The Avios decoder only cares about the raw frames. A H264 frame is also called a NALU.

There's a lot of documents online about NALU stream such as AnnexB but here's a start:

http://stackoverflow.com/a/24890903/424124  
http://stackoverflow.com/a/20686267/424124  

## Contact

Josh Baker [@tidwall](https://twitter.com/tidwall)

## License

Avios source code is available under the MIT [License](LICENSE)


