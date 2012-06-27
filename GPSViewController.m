//
//  GPSViewController.m
//  ARIS
//
//  Created by Ben Longoria on 2/11/09.
//  Copyright 2009 University of Wisconsin. All rights reserved.
//

#import "GPSViewController.h"
#import "AppModel.h"
#import "AppServices.h"
#import "Location.h"
#import "Player.h"
#import "ARISAppDelegate.h"
#import "AnnotationView.h"
#import "Media.h"
#import "Annotation.h"
#import <UIKit/UIActionSheet.h>
#import "NoteDetailsViewController.h"
#import "NoteEditorViewController.h"

static float INITIAL_SPAN = 0.001;
@implementation GPSViewController

@synthesize locations, route;
@synthesize mapView;
@synthesize tracking,mapTrace;
@synthesize mapTypeButton;
@synthesize playerTrackingButton;
@synthesize toolBar,addMediaButton;
@synthesize playerButton;

//Override init for passing title and icon to tab bar
- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    self = [super initWithNibName:nibName bundle:nibBundle];
    if (self) {
        self.title = NSLocalizedString(@"MapViewTitleKey",@"");
        self.tabBarItem.image = [UIImage imageNamed:@"103-map"];

		tracking = YES;
		playerTrackingButton.style = UIBarButtonItemStyleDone;
        route = [[NSMutableArray alloc]initWithCapacity:10];
		
		//register for notifications
		NSNotificationCenter *dispatcher = [NSNotificationCenter defaultCenter];
        [dispatcher addObserver:self selector:@selector(removeLoadingIndicator) name:@"ConnectionLost" object:nil];

		[dispatcher addObserver:self selector:@selector(refresh) name:@"PlayerMoved" object:nil];
		[dispatcher addObserver:self selector:@selector(removeLoadingIndicator) name:@"ReceivedLocationList" object:nil];
		[dispatcher addObserver:self selector:@selector(refreshViewFromModel) name:@"NewLocationListReady" object:nil];
		[dispatcher addObserver:self selector:@selector(silenceNextUpdate) name:@"SilentNextUpdate" object:nil];
		
	}
	
    return self;
}

- (void)silenceNextUpdate {
	silenceNextServerUpdateCount++;
}
		
- (IBAction)changeMapType: (id) sender {
	ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate playAudioAlert:@"ticktick" shouldVibrate:NO];
	
	switch (mapView.mapType) {
		case MKMapTypeStandard:
			mapView.mapType=MKMapTypeSatellite;
			break;
		case MKMapTypeSatellite:
			mapView.mapType=MKMapTypeHybrid;
			break;
		case MKMapTypeHybrid:
			mapView.mapType=MKMapTypeStandard;
			break;
	}
}

- (IBAction)refreshButtonAction{
	NSLog(@"GPSViewController: Refresh Button Touched");
	
	ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate playAudioAlert:@"ticktick" shouldVibrate:NO];
	
	//resume auto centering
	tracking = YES;
	playerTrackingButton.style = UIBarButtonItemStyleDone;

	
	//Force a location update
	[[[MyCLController sharedMyCLController] locationManager] stopUpdatingLocation];
	[[[MyCLController sharedMyCLController]locationManager] startUpdatingLocation];

	//Rerfresh all contents
	[self refresh];

}
-(void)playerButtonTouch{
    [AppModel sharedAppModel].hidePlayers = ![AppModel sharedAppModel].hidePlayers;
    if([AppModel sharedAppModel].hidePlayers){
        [playerButton setStyle:UIBarButtonItemStyleBordered];
        if (mapView) {
            NSEnumerator *existingAnnotationsEnumerator = [[[mapView annotations] copy] objectEnumerator];
            Annotation *annotation;
            while (annotation = [existingAnnotationsEnumerator nextObject]) {
                if (annotation != mapView.userLocation && annotation.kind == NearbyObjectPlayer) [mapView removeAnnotation:annotation];
            }
        }
    }
    else{
        [playerButton setStyle:UIBarButtonItemStyleDone];  
    }
	[[[MyCLController sharedMyCLController] locationManager] stopUpdatingLocation];
	[[[MyCLController sharedMyCLController]locationManager] startUpdatingLocation];
    
	//Refresh all contents
    tracking = NO;
	[self refresh];
}

- (IBAction)addMediaButtonAction: (id) sender{
    NoteEditorViewController *noteVC = [[NoteEditorViewController alloc] initWithNibName:@"NoteEditorViewController" bundle:nil];
    noteVC.delegate = self;
    [self.navigationController pushViewController:noteVC animated:YES];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	
	NSLog(@"Begin Loading GPS View");
	mapView.showsUserLocation = YES;
	[mapView setDelegate:self];
	[self.view addSubview:mapView];
	NSLog(@"GPSViewController: Mapview inited and added to view");
	
	
	//Setup the buttons
	mapTypeButton.target = self; 
	mapTypeButton.action = @selector(changeMapType:);
	mapTypeButton.title = NSLocalizedString(@"MapTypeKey",@"");
	
	playerTrackingButton.target = self; 
	playerTrackingButton.action = @selector(refreshButtonAction);
	playerTrackingButton.style = UIBarButtonItemStyleDone;

    addMediaButton.target = self;
    addMediaButton.action = @selector(addMediaButtonAction:);
	
	//Force an update of the locations
	[[AppServices sharedAppServices] forceUpdateOnNextLocationListFetch];
	
	[self refresh];	
	
	NSLog(@"GPSViewController: View Loaded");
}

- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"GPSViewController: view did appear");

    
    if (![AppModel sharedAppModel].loggedIn || [AppModel sharedAppModel].currentGame.gameId==0) {
        NSLog(@"GPSViewController: Player is not logged in, don't refresh");
        return;
    }
    
	[[AppServices sharedAppServices] updateServerMapViewed];
	
	[self refresh];		
	
	self.tabBarItem.badgeValue = nil;
	newItemsSinceLastView = 0;
	silenceNextServerUpdateCount = 0;
    [AppModel sharedAppModel].hidePlayers = ![AppModel sharedAppModel].hidePlayers;
    [self playerButtonTouch];
	//create a time for automatic map refresh
	NSLog(@"GPSViewController: Starting Refresh Timer");
	if (refreshTimer != nil && [refreshTimer isValid]) [refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
}

-(void)dismissTutorial{
	ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate.tutorialViewController dismissTutorialPopupWithType:tutorialPopupKindMapTab];
}


// Updates the map to current data for player and locations from the server
- (void) refresh {
	if (mapView) {
		NSLog(@"GPSViewController: refresh requested");	
	
		if ([AppModel sharedAppModel].loggedIn && ([AppModel sharedAppModel].currentGame.gameId != 0 && [AppModel sharedAppModel].playerId != 0)) {
            [[AppServices sharedAppServices] fetchLocationList];
            [self showLoadingIndicator];
        }

		//Zoom and Center
		if (tracking) [self zoomAndCenterMap];
       /* if(mapTrace){
            [self.route addObject:[AppModel sharedAppModel].playerLocation];
            MKPolyline *line = [[MKPolyline alloc]init];
            line 
            
        }*/

	} 
    else {
		NSLog(@"GPSViewController: refresh requested but ignored, as mapview is nil");	
		
	}
}

-(void) zoomAndCenterMap {
	
	appSetNextRegionChange = YES;
	
	//Center the map on the player
	MKCoordinateRegion region = mapView.region;
	region.center = [AppModel sharedAppModel].playerLocation.coordinate;
	region.span = MKCoordinateSpanMake(INITIAL_SPAN, INITIAL_SPAN);

	[mapView setRegion:region animated:YES];
		
}

-(void)showLoadingIndicator{
	UIActivityIndicatorView *activityIndicator = 
	[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	UIBarButtonItem * barButton = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
	[[self navigationItem] setRightBarButtonItem:barButton];
	[activityIndicator startAnimating];
}

-(void)removeLoadingIndicator{
	[[self navigationItem] setRightBarButtonItem:nil];
	NSLog(@"GPSViewController: removeLoadingIndicator: silenceNextServerUpdateCount = %d", silenceNextServerUpdateCount);
    [self refreshViewFromModel];
}


- (void)refreshViewFromModel {
    if (mapView) {
    NSMutableArray *newLocationsArray;
    Annotation *annotation;
    ARISAppDelegate *appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	NSLog(@"GPSViewController: Refreshing view from model");
	
	NSLog(@"GPSViewController: refreshViewFromModel: silenceNextServerUpdateCount = %d", silenceNextServerUpdateCount);

	if (silenceNextServerUpdateCount < 1) {
		//Check if anything is new since last time or item has disappeared
        int annotationsRemoved = 0;
		newLocationsArray = [AppModel sharedAppModel].locationList;
		for (int i = 0; i < [[mapView annotations] count]; i++) {
            BOOL match = NO;
			NSObject <MKAnnotation>  *testAnnotation = [[mapView annotations] objectAtIndex:i];
            if([testAnnotation isKindOfClass: [Annotation class]]) {
                annotation = (Annotation *)testAnnotation;
            for (int j = 0; j < [newLocationsArray count]; j++) {
                NSLog(@"Compare to: %d, %d", annotation.location.locationId, ((Location *)[newLocationsArray objectAtIndex:j]).locationId);
				if ([annotation.location compareTo:[newLocationsArray objectAtIndex:j]]){
                    [newLocationsArray removeObjectAtIndex:j];
                    j--;
                    match = YES;
                    NSLog(@"Match");
                }	
			}
            if(!match && [newLocationsArray count] != 0){
                newItemsSinceLastView -= [newLocationsArray count];
                if(newItemsSinceLastView < 0) newItemsSinceLastView = 0;
                [mapView removeAnnotation:annotation];
                annotationsRemoved++;
                i--;
			}
            }
		}
        
        newItemsSinceLastView -= annotationsRemoved;
        newItemsSinceLastView += [newLocationsArray count];

		if (newItemsSinceLastView > 0 && ![appDelegate.tabBarController.selectedViewController.title isEqualToString:@"Map"]) {
			self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%d",newItemsSinceLastView];
			
			if (![AppModel sharedAppModel].hasSeenMapTabTutorial) {
				//Put up the tutorial tab
				ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
				[appDelegate.tutorialViewController showTutorialPopupPointingToTabForViewController:self.navigationController 
																							   type:tutorialPopupKindMapTab 
																							  title:@"New GPS Location" 
																							message:@"You have a new place of interest on your GPS! Touch below to view the Map."];						

				[AppModel sharedAppModel].hasSeenMapTabTutorial = YES;
                [self performSelector:@selector(dismissTutorial) withObject:nil afterDelay:5.0];
			}
		}
		else{
           newItemsSinceLastView = 0;
           self.tabBarItem.badgeValue = nil; 
        }
	}

	self.locations = [AppModel sharedAppModel].locationList;
    
    if([appDelegate.tabBarController.selectedViewController.title isEqualToString:@"Map"]) {
		//Add the freshly loaded locations from the notification
		for ( Location* location in newLocationsArray ) {
			NSLog(@"GPSViewController: Adding location annotation for:%@ id:%d", location.name, location.locationId);
			if (location.hidden == YES) 
			{
				NSLog(@"No I'm not, because this location is hidden.");
				continue;
			}
			CLLocationCoordinate2D locationLatLong = location.location.coordinate;
			
			Annotation *annotation = [[Annotation alloc]initWithCoordinate:locationLatLong];
			annotation.location = location;
			annotation.title = location.name;
			if (location.kind == NearbyObjectItem && location.qty > 1) 
				annotation.subtitle = [NSString stringWithFormat:@"x %d",location.qty];
			annotation.iconMediaId = location.iconMediaId;
			annotation.kind = location.kind;

			[mapView addAnnotation:annotation];
			if (!mapView) {
				NSLog(@"GPSViewController: Just added an annotation to a null mapview!");
			}
		}
        }
     	if (silenceNextServerUpdateCount>0) silenceNextServerUpdateCount--;   
	}
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
   
    NSLog(@"GPSViewController: Releasing Memory");
    //Blow away the old markers except for the player marker
    NSEnumerator *existingAnnotationsEnumerator = [[[mapView annotations] copy] objectEnumerator];
    NSObject <MKAnnotation> *annotation;
    while (annotation = [existingAnnotationsEnumerator nextObject]) {
        if (annotation != mapView.userLocation) [mapView removeAnnotation:annotation];
    }
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

}

-(UIImage *)addTitle:(NSString *)imageTitle quantity:(int)quantity toImage:(UIImage *)img {
	
	NSString *calloutString;
	if (quantity > 1) {
		calloutString = [NSString stringWithFormat:@"%@:%d",imageTitle, quantity];
	} else {
		calloutString = imageTitle;
	}
 	UIFont *myFont = [UIFont fontWithName:@"Arial" size:12];
	CGSize textSize = [calloutString sizeWithFont:myFont];
	CGRect textRect = CGRectMake(0, 0, textSize.width + 10, textSize.height);
	
	//callout path
	CGMutablePathRef calloutPath = CGPathCreateMutable();
	CGPoint pointerPoint = CGPointMake(textRect.origin.x + 0.6 * textRect.size.width,  textRect.origin.y + textRect.size.height + 5);
	CGPathMoveToPoint(calloutPath, NULL, textRect.origin.x, textRect.origin.y);
	CGPathAddLineToPoint(calloutPath, NULL, textRect.origin.x, textRect.origin.y + textRect.size.height);
	CGPathAddLineToPoint(calloutPath, NULL, pointerPoint.x - 5.0, textRect.origin.y + textRect.size.height);
	CGPathAddLineToPoint(calloutPath, NULL, pointerPoint.x, pointerPoint.y);
	CGPathAddLineToPoint(calloutPath, NULL, pointerPoint.x + 5.0, textRect.origin.y+ textRect.size.height);
	CGPathAddLineToPoint(calloutPath, NULL, textRect.origin.x + textRect.size.width, textRect.origin.y + textRect.size.height);
	CGPathAddLineToPoint(calloutPath, NULL, textRect.origin.x + textRect.size.width, textRect.origin.y);
	CGPathAddLineToPoint(calloutPath, NULL, textRect.origin.x, textRect.origin.y);
	
	
	
	CGRect imageRect = CGRectMake(0, textSize.height + 10.0, img.size.width, img.size.height);
	CGRect backgroundRect = CGRectUnion(textRect, imageRect);
	if (backgroundRect.size.width > img.size.width) {
		imageRect.origin.x = (backgroundRect.size.width - img.size.width) / 2.0;
	}
	
	CGSize contextSize = backgroundRect.size;
	UIGraphicsBeginImageContext(contextSize);
	CGContextAddPath(UIGraphicsGetCurrentContext(), calloutPath);
	[[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.6] set];
	CGContextFillPath(UIGraphicsGetCurrentContext());
	[[UIColor blackColor] set];
	CGContextAddPath(UIGraphicsGetCurrentContext(), calloutPath);
	CGContextStrokePath(UIGraphicsGetCurrentContext());
	[img drawAtPoint:imageRect.origin];
	[calloutString drawInRect:textRect withFont:myFont lineBreakMode:UILineBreakModeWordWrap alignment:UITextAlignmentCenter];
	UIImage *returnImage = UIGraphicsGetImageFromCurrentImageContext();
	CGPathRelease(calloutPath);
	UIGraphicsEndImageContext();
	
	return returnImage;
}



#pragma mark MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
	//User must have moved the map. Turn off Tracking
	NSLog(@"GPSVC: regionDidChange delegate metohd fired");

	if (!appSetNextRegionChange) {
		NSLog(@"GPSVC: regionDidChange without appSetNextRegionChange, it must have been the user");
		tracking = NO;
		playerTrackingButton.style = UIBarButtonItemStyleBordered;
	}
	
	appSetNextRegionChange = NO;

}

- (MKAnnotationView *)mapView:(MKMapView *)myMapView viewForAnnotation:(id <MKAnnotation>)annotation{
	NSLog(@"GPSViewController: In viewForAnnotation");

	
	//Player
	if (annotation == mapView.userLocation)
	{
		NSLog(@"GPSViewController: Getting the annotation view for the user's location");
		 return nil; //Let it do it's own thing
	}
	
	//Everything else
	else {
		NSLog(@"GPSViewController: Getting the annotation view for a game object: %@", annotation.title);
		AnnotationView *annotationView=[[AnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:nil];
        
		return annotationView;
	}
}

- (void)mapView:(MKMapView *)aMapView didSelectAnnotationView:(MKAnnotationView *)view {
	Location *location = ((Annotation*)view.annotation).location;
    if(view.annotation == aMapView.userLocation) return;
	NSLog(@"GPSViewController: didSelectAnnotationView for location: %@",location.name);
	
	//Set up buttons
	NSMutableArray *buttonTitles = [NSMutableArray arrayWithCapacity:1];
	int cancelButtonIndex = 0;
	if (location.allowsQuickTravel)	{
		[buttonTitles addObject: @"Quick Travel"];
		cancelButtonIndex = 1;
	}
	[buttonTitles addObject: @"Cancel"];
	
	
	//Create and Display Action Sheet
	UIActionSheet *actionSheet = [[UIActionSheet alloc]initWithTitle:location.name 
															delegate:self 
												   cancelButtonTitle:nil 
											  destructiveButtonTitle:nil 
												   otherButtonTitles:nil];
	actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	actionSheet.cancelButtonIndex = cancelButtonIndex;
	
	for (NSString *title in buttonTitles) {
		[actionSheet addButtonWithTitle:title];
	}
	
	[actionSheet showInView:view];
    
}


- (void)mapView:(MKMapView *)mV didAddAnnotationViews:(NSArray *)views { 

    
    // Step through all annotations
    Annotation *ann;
    for (id<MKAnnotation> annotation in mV.annotations){

        ann = (Annotation *) annotation;
        if (ann.title != NULL && ![ann.title isEqualToString:@"Current Location"]) {  // Skip if not a normal item that won't have a wiggle property
            MKAnnotationView* aV = [mapView viewForAnnotation: annotation];  // get annotationView for Annotation
            if (aV){
                // step through added views and check if this is an added view 
                BOOL bNewView = NO;
                MKAnnotationView *addedView;
                for (addedView in views) {
                    if (aV == addedView) {
                        bNewView = YES;
                    }
                }
                // prepare drop animation
                CGRect endFrame = aV.frame;        
                if (bNewView == YES) {
                    aV.frame = CGRectMake(aV.frame.origin.x, aV.frame.origin.y - 230.0, aV.frame.size.width, aV.frame.size.height);
                
                    // if annotation should wiggle, drop and wiggle
                    if (ann.location.wiggle == 1) {  
                        [UIView animateWithDuration:0.45 delay:0.0 options:NULL animations:^{
                            [aV setFrame:endFrame];
                        } completion:^(BOOL finished) {
                            if (finished) {
                                [self wiggleWithAnnotationView:aV];
                            }
                        }];
                        
                    //else, only drop
                    } else {  
                        [UIView animateWithDuration:0.45 delay:0.0 options:NULL animations:^{
                            [aV setFrame:endFrame];
                        } completion:^(BOOL finished) {
                        }];
                    }
                }
                
            }
        }
    }
}

- (void) wiggleWithAnnotationView:(MKAnnotationView *) aV {
    // wiggle annotation up and down repeatedly
    [UIView animateWithDuration:0.35 delay:0.0 options:NULL animations:^{
    [aV setFrame:CGRectMake(aV.frame.origin.x, aV.frame.origin.y - 10.0, aV.frame.size.width, aV.frame.size.height)];
    } completion:^(BOOL finished) {
        if (finished) { 
            [UIView animateWithDuration:0.35 delay:0.0 options:NULL animations:^{
                [aV setFrame:CGRectMake(aV.frame.origin.x, aV.frame.origin.y + 10.0, aV.frame.size.width, aV.frame.size.height)];
            } completion:^(BOOL finished) {
                if (finished) {
                    [self wiggleWithAnnotationView:aV];
                }
            }];
        }
    }];
}


    


#pragma mark UIActionSheet Delegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
	NSLog(@"GPSViewController: action sheet button %d was clicked",buttonIndex);
	
	Annotation *currentAnnotation = [mapView.selectedAnnotations lastObject];
	
	if (buttonIndex == actionSheet.cancelButtonIndex) [mapView deselectAnnotation:currentAnnotation animated:YES]; 
	else {
        [currentAnnotation.location display];
        [mapView deselectAnnotation:currentAnnotation animated:YES];
    }

}



@end
