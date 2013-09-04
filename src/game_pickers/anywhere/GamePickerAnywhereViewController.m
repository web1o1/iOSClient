//
//  GamePickerAnywhereViewController.m
//  ARIS
//
//  Created by Ben Longoria on 2/13/09.
//  Copyright 2009 University of Wisconsin. All rights reserved.
//

#include <QuartzCore/QuartzCore.h>
#import "GamePickerAnywhereViewController.h"
#import "AppModel.h"
#import "AppServices.h"
#import "Game.h"
#import "GameDetailsViewController.h"
#import "GamePickerCell.h"

@implementation GamePickerAnywhereViewController

- (id) initWithViewFrame:(CGRect)f delegate:(id<GamePickerViewControllerDelegate>)d
{
    if(self = [super initWithViewFrame:f delegate:d])
    {
        self.title = NSLocalizedString(@"GamePickerAnywhereTabKey", @"");
        [self.tabBarItem setFinishedSelectedImage:[UIImage imageNamed:@"globe_selected.png"] withFinishedUnselectedImage:[UIImage imageNamed:@"globe_unselected.png"]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshViewFromModel) name:@"NewAnywhereGameListReady" object:nil];
    }
    return self;
}

- (void) requestNewGameList
{
    [super requestNewGameList];
    
    if([AppModel sharedAppModel].player.location && [[AppModel sharedAppModel] player])
    {
        [[AppServices sharedAppServices] fetchAnywhereGameList];
        [self showLoadingIndicator];
    }
}

- (void) refreshViewFromModel
{
	self.gameList = [[AppModel sharedAppModel].anywhereGameList sortedArrayUsingSelector:@selector(compareCalculatedScore:)];
    [self.gameTable reloadData];
    
    [self removeLoadingIndicator];
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end