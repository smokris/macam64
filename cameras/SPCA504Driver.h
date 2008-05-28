//
//  SPCA504Driver.h
//  macam
//
//  Created by Harald on 11/14/07.
//  Copyright 2007 HXR. All rights reserved.
//


#import <SPCA5XXDriver.h>


enum 
{
    AnySPCA504 = 1,
    LogitechClickSmart420,
    AiptekMiniPenCam13,
    MegapixV4, 
    LogitechClickSmart820,
};


@interface SPCA504ADriver : SPCA5XXDriver 
{}

@end


@interface SPCA504BDriver : SPCA504ADriver 
{}

@end


@interface SPCA504B_P3Driver : SPCA504BDriver 
{}

@end


@interface SPCA504CDriver : SPCA504BDriver 
{}

@end


@interface SPCA504ADriverAiptekMiniCam : SPCA504ADriver 
{}

@end


@interface SPCA504CDriverClickSmart420 : SPCA504CDriver 
{}

@end
