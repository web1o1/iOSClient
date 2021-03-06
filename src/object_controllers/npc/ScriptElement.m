//
//  ScriptElement.m
//  aris-conversation
//
//  Created by Kevin Harris on 09/11/18.
//  Copyright 2009 Studio Tectorum. All rights reserved.
//

#import "ScriptElement.h"

@implementation ScriptElement

@synthesize title;
@synthesize text;

@synthesize type;
@synthesize typeId;

@synthesize mediaId;

@synthesize imageRect;
@synthesize zoomTime;

@synthesize vibrate;
@synthesize notification;

- (id) init
{
	if ((self = [super init]))
    {
        self.title        = nil;
        self.text         = nil;
        
        self.type         = @"pc";
        self.typeId       = 0;
        
        self.mediaId      = 0;

        self.imageRect    = CGRectMake(0, 0, 320, [UIScreen mainScreen].applicationFrame.size.height-44);
        self.zoomTime     = 0;
        
        self.vibrate      = NO;
        self.notification = nil;
	}
	return self;
}


@end
