//
//  NearbyObjectsViewController.m
//  ARIS
//
//  Created by David J Gagnon on 2/13/11.
//  Copyright 2011 University of Wisconsin. All rights reserved.
//

#import "NearbyObjectsViewController.h"
#import "StateControllerProtocol.h"
#import "AppModel.h"
#import "ARISAppDelegate.h"
#import "AppServices.h"
#import "NearbyObjectCell.h"
#import "Player.h"

@interface NearbyObjectsViewController() <ARISMediaViewDelegate>
{
    NSMutableArray *nearbyLocationsList;
	IBOutlet UITableView *nearbyTable;
    
    id<NearbyObjectsViewControllerDelegate, StateControllerProtocol> __unsafe_unretained delegate;
}

@property (nonatomic, strong) NSMutableArray *nearbyLocationsList;

@end

@implementation NearbyObjectsViewController

@synthesize nearbyLocationsList;

- (id) initWithDelegate:(id<NearbyObjectsViewControllerDelegate, StateControllerProtocol>)d
{
    if(self = [super initWithNibName:@"NearbyObjectsViewController" bundle:nil delegate:d])
    {
        self.tabID = @"NEARBY";
        self.tabIconName = @"radar";
        
        delegate = d;
        
        self.title = NSLocalizedString(@"NearbyObjectsTabKey",@"");
		self.navigationItem.title = NSLocalizedString(@"NearbyObjectsTitleKey",@"");
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshViewFromModel) name:@"PlayerMoved"        object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshViewFromModel) name:@"LocationsAvailable" object:nil];
		self.nearbyLocationsList = [NSMutableArray arrayWithCapacity:5];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) viewDidAppear:(BOOL)animated
{
	[self refresh];
    self.tabBarItem.badgeValue = nil;
}

- (void) refresh
{
    [[AppServices sharedAppServices] fetchPlayerLocationList];
}

- (void) refreshViewFromModel
{
    NSMutableArray *newNearbyLocationsList = [NSMutableArray arrayWithCapacity:5];
    
    Location *forceLocation;
    
    //Find locations that are "nearby" from the list of all locations
    for(Location *location in [AppModel sharedAppModel].currentGame.locationsModel.currentLocations)
    {
        if(location.gameObject.type == GameObjectItem) ((Item *)location.gameObject).qty = location.qty;
        BOOL match = NO;
        for(Location *oldLocation in self.nearbyLocationsList)
            if(oldLocation.locationId == location.locationId) match = YES;
        if(!match && [[AppModel sharedAppModel].player.location distanceFromLocation:location.latlon] < location.errorRange &&
           (location.gameObject.type != GameObjectItem || location.qty != 0) && location.gameObject.type != GameObjectPlayer)
            [newNearbyLocationsList addObject:location];
        else if(match && (location.errorRange >= 2147483637 || [[AppModel sharedAppModel].player.location distanceFromLocation:location.latlon] < location.errorRange+10) &&
           (location.gameObject.type != GameObjectItem || location.qty != 0) && location.gameObject.type != GameObjectPlayer)
            [newNearbyLocationsList addObject:location];
    }
    
    //Find new nearby locations to be force displayed
    for(Location *location in newNearbyLocationsList)
    {
        BOOL match = NO;
        for(Location *oldLocation in self.nearbyLocationsList)
            if(oldLocation.locationId == location.locationId) match = YES;
        if(match == NO && location.forcedDisplay)
            forceLocation = location;
    }
    
    if(forceLocation)
    {
        if([delegate displayGameObject:forceLocation.gameObject fromSource:forceLocation])
            [self.nearbyLocationsList addObject:forceLocation];
    }
    else
    {
        BOOL shouldPlaySound = NO;
        BOOL match = NO;
        for(Location *newLocation in newNearbyLocationsList)
        {
            for(Location *oldLocation in self.nearbyLocationsList)
            {
                if(newLocation.locationId == oldLocation.locationId) match = YES;
            }
            if(!match) shouldPlaySound = YES;
        }
        if(shouldPlaySound) [(ARISAppDelegate *)[[UIApplication sharedApplication] delegate] playAudioAlert:@"nearbyObject" shouldVibrate:NO];
        
        self.nearbyLocationsList = newNearbyLocationsList; //Throw out new locations list
    }
    
    if([self.nearbyLocationsList count] == 0)
        self.navigationController.tabBarItem.badgeValue = nil; //hide
    else
        self.navigationController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%d",[self.nearbyLocationsList count]]; //show
    
    [nearbyTable reloadData];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.nearbyLocationsList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
    NearbyObjectCell *cell = (NearbyObjectCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
	if(cell == nil)
    {
		ARISViewController *temporaryController = [[ARISViewController alloc] initWithNibName:@"NearbyObjectCell" bundle:nil];
		cell = (NearbyObjectCell *)temporaryController.view;
	}
	
	Location *l = [self.nearbyLocationsList objectAtIndex:indexPath.row];
	
	if (l.gameObject.type == GameObjectItem && l.qty > 1) cell.title.text = [NSString stringWithFormat:@"%@ (x%d)",l.name,l.qty];
	else cell.title.text = l.name;
	
    [cell.iconView refreshWithFrame:cell.iconView.frame media:[[AppModel sharedAppModel] mediaForMediaId:l.gameObject.iconMediaId ofType:@"PHOTO"] mode:ARISMediaDisplayModeAspectFit delegate:self];
    
	return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Location *l = [self.nearbyLocationsList objectAtIndex:indexPath.row];
	[delegate displayGameObject:l.gameObject fromSource:l];
}

- (void) ARISMediaViewUpdated:(ARISMediaView *)amv
{
    
}

@end
