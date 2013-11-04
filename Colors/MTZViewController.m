//
//  MTZViewController.m
//  Colors
//
//  Created by Matt Zanchelli on 9/2/13.
//  Copyright (c) 2013 Matt Zanchelli. All rights reserved.
//

#import "MTZViewController.h"

@import MediaPlayer;

#import "UIColor+ColorFinder.h"
#import "UIColor+Components.h"
#import "UIColor+DeviceColor.h"
#import "UIColor+Hex.h"
#import "UIColor+KeyColor.h"
#import "UIColor+Manipulation.h"
#import "UIColor+NeueColors.h"
#import "UIImage+Colors.h"
#import "UIImage+Crop.h"

#import "MTZSlider.h"

@interface MTZViewController () <MPMediaPickerControllerDelegate>

@property (strong, nonatomic) MPMusicPlayerController *player;
@property (strong, nonatomic) IBOutlet UIImageView *iv;

@property (strong, nonatomic) IBOutlet MTZSlider *trackSlider;
@property (strong, nonatomic) IBOutlet MTZSlider *volumeSlider;

@property (strong, nonatomic) IBOutlet UILabel *trackTitle;
@property (strong, nonatomic) IBOutlet UILabel *artistAndAlbumTitles;

@property (strong, nonatomic) UILabel *trackNumbersLabel;

@property (strong, nonatomic) IBOutlet UINavigationBar *navigationBar;

@property (strong, nonatomic) IBOutlet UIView *controlsView;

@property (strong, nonatomic) IBOutlet UIImageView *topShadow;
@property (strong, nonatomic) IBOutlet UIImageView *bottomShadow;

@property (strong, nonatomic) IBOutlet UILabel *timeElapsed;
@property (strong, nonatomic) IBOutlet UILabel *timeRemaining;

@property (strong, nonatomic) IBOutlet UIButton *playPause;

@property (strong, nonatomic) MPMediaPickerController *mediaPicker;

@property (strong, nonatomic) NSTimer *pollElapsedTime;

@property (strong, nonatomic) IBOutlet UIImageView *speakerOffImage;

@end

@implementation MTZViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	_player = [MPMusicPlayerController iPodMusicPlayer];
	
	// Add volume view to hide volume HUD when changing volume
	MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1280.0, -1280.0, 0.0f, 0.0f)];
	[self.view addSubview:volumeView];
	
	_trackSlider = [[MTZSlider alloc] initWithFrame:(CGRect){52,1,216,34}];
	[_trackSlider addTarget:self
					 action:@selector(trackSliderChangedValue:)
		   forControlEvents:UIControlEventValueChanged];
	[_trackSlider addTarget:self
					 action:@selector(trackSliderDidBegin:)
		   forControlEvents:UIControlEventTouchDown];
	[_trackSlider addTarget:self
					 action:@selector(trackSliderDidEnd:)
		   forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchDragExit|UIControlEventTouchCancel];
	_trackSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_trackSlider.fillImage = [UIImage imageNamed:@"ProgressFill"];
	_trackSlider.trackImage = [UIImage imageNamed:@"ProgressTrack"];
	[_trackSlider setThumbImage:[UIImage imageNamed:@"ProgressThumb"]
					   forState:UIControlStateNormal];
	[_controlsView addSubview:_trackSlider];
	
	_volumeSlider = [[MTZSlider alloc] initWithFrame:(CGRect){52,121,216,34}];
	[_volumeSlider addTarget:self
					  action:@selector(volumeChanged:)
			forControlEvents:UIControlEventValueChanged];
	_volumeSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_volumeSlider.value = _player.volume;
	_volumeSlider.fillImage = [UIImage imageNamed:@"VolumeFill"];
	_volumeSlider.trackImage = [UIImage imageNamed:@"VolumeTrack"];
	[_volumeSlider setThumbImage:[UIImage imageNamed:@"VolumeThumb"]
						forState:UIControlStateNormal];
	[_controlsView addSubview:_volumeSlider];
	
	UIInterpolatingMotionEffect *verticalMotion = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
	verticalMotion.minimumRelativeValue = @2;
	verticalMotion.maximumRelativeValue = @-2;
	_topShadow.motionEffects = @[verticalMotion];
	_bottomShadow.motionEffects = @[verticalMotion];
	
	_trackNumbersLabel = [[UILabel alloc] initWithFrame:(CGRect){0,0,160,32}];
	_trackNumbersLabel.textAlignment = NSTextAlignmentCenter;
	_trackNumbersLabel.text = @"Now Playing";
	
	self.navigationBar.topItem.titleView = _trackNumbersLabel;
	[self.navigationBar.topItem setHidesBackButton:NO animated:NO];
	
	_mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    _mediaPicker.delegate = self;
    _mediaPicker.allowsPickingMultipleItems = YES;
	
	// Register for media player notifications
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(songChanged:)
                               name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                             object:_player];
	[notificationCenter addObserver:self
						   selector:@selector(playbackStateDidChange:)
							   name:MPMusicPlayerControllerPlaybackStateDidChangeNotification
							 object:_player];
	[notificationCenter addObserver:self
						   selector:@selector(volumeDidChange:)
							   name:MPMusicPlayerControllerVolumeDidChangeNotification
							 object:_player];
    [_player beginGeneratingPlaybackNotifications];
	
	[self checkPlaybackStatus];
	[self updatePlaybackTime];
}

- (void)checkPlaybackStatus
{
	if ( _player.playbackState == MPMusicPlaybackStatePlaying ) {
		[_playPause setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
	} else {
		[_playPause setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
	}
}

- (void)songChanged:(id)sender
{
	MPMediaItem *currentItem = [_player nowPlayingItem];
    MPMediaItemArtwork *artwork = [currentItem valueForProperty:MPMediaItemPropertyArtwork];
	UIImage *albumArtwork = [artwork imageWithSize:CGSizeMake(320, 320)];
    _iv.image = albumArtwork;
	[self refreshColors];
	
	NSString *trackTitle = [currentItem valueForProperty:MPMediaItemPropertyTitle];
	if ( !trackTitle ) trackTitle = @"Song";
	_trackTitle.text = trackTitle;
	NSString *artist = [currentItem valueForProperty:MPMediaItemPropertyArtist];
	if ( !artist ) artist = @"Artist";
	NSString *album = [currentItem valueForProperty:MPMediaItemPropertyAlbumTitle];
	if ( !album ) album = @"Album";
	_artistAndAlbumTitles.text = [NSString stringWithFormat:@"%@ - %@", artist, album];
	
	
	NSNumber *trackNo = [currentItem valueForProperty:MPMediaItemPropertyAlbumTrackNumber];
	NSNumber *trackOf = [currentItem valueForProperty:MPMediaItemPropertyAlbumTrackCount];
	
	if ( trackNo && trackOf ) {
		NSString *title = [NSString stringWithFormat:@"%@ of %@", trackNo, trackOf];
		NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];
		NSUInteger length = [NSString stringWithFormat:@"%@", trackNo].length;
		[attributedTitle addAttribute:NSFontAttributeName
								value:[UIFont boldSystemFontOfSize:15.0f]
								range:NSMakeRange(0, length)];
		[attributedTitle addAttribute:NSFontAttributeName
								value:[UIFont systemFontOfSize:15.0f]
								range:NSMakeRange(length, 4)];
		[attributedTitle addAttribute:NSFontAttributeName
								value:[UIFont boldSystemFontOfSize:15.0f]
								range:NSMakeRange(length + 4, [NSString stringWithFormat:@"%@", trackOf].length)];
		_trackNumbersLabel.attributedText = attributedTitle;
	} else {
		_trackNumbersLabel.text = @"Now Playing";
	}
	
	NSNumber *playbackDuration = [currentItem valueForProperty:MPMediaItemPropertyPlaybackDuration];
	_trackSlider.maximumValue = playbackDuration.floatValue;
	
	[self updatePlaybackTime];
}

- (void)updatePlaybackTime
{
	[self updatePlaybackTimeForTime:_player.currentPlaybackTime withAnimation:NO];
}

- (void)updatePlaybackTimeWithAnimation
{
	[self updatePlaybackTimeForTime:_player.currentPlaybackTime withAnimation:YES];
}

- (void)updatePlaybackTimeForTime:(NSTimeInterval)elapsed withAnimation:(BOOL)animated
{
	if ( animated ) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationCurve:UIViewAnimationCurveLinear];
		[UIView setAnimationDuration:1.0f];
		[_trackSlider setValue:(elapsed + 0.5f) animated:YES];
		[UIView commitAnimations];
	} else {
		[_trackSlider setValue:(elapsed) animated:NO];
	}
	
	CGFloat minutes, seconds;
	NSString *secondsString, *minutesString;
	
	minutes = floor(elapsed / 60);
	seconds = roundf(elapsed - minutes * 60);
	if ( isnan(seconds) ) {
		secondsString = @"--";
	} else if ( seconds < 10 ) {
		secondsString = [NSString stringWithFormat:@"0%.0f", seconds];
	} else {
		secondsString = [NSString stringWithFormat:@"%.0f", seconds];
	}
	
	if ( isnan(minutes) ) {
		minutesString = @"--";
	} else {
		minutesString = [NSString stringWithFormat:@"%.0f", MAX(0,minutes)];
	}
	
	_timeElapsed.text = [NSString stringWithFormat:@"%@:%@", minutesString, secondsString];
	
	MPMediaItem *currentItem = [_player nowPlayingItem];
	NSNumber *playbackDuration = [currentItem valueForProperty:MPMediaItemPropertyPlaybackDuration];
	
#warning round playbackDuration to nearest second?
	NSTimeInterval remaining = playbackDuration.floatValue - elapsed;
	minutes = floor(remaining / 60);
	seconds = round(remaining - minutes * 60);
	if ( isnan(seconds) ){
		secondsString = @"--";
	} else if ( seconds < 10 ) {
		secondsString = [NSString stringWithFormat:@"0%.0f", seconds];
	} else {
		secondsString = [NSString stringWithFormat:@"%.0f", seconds];
	}
	
	if ( isnan(minutes) ) {
		minutesString = @"--";
	} else {
		minutesString = [NSString stringWithFormat:@"-%.0f", MAX(0,minutes)];
	}
	
	_timeRemaining.text = [NSString stringWithFormat:@"%@:%@", minutesString, secondsString];
}

- (void)playbackStateDidChange:(id)sender
{
	switch ( _player.playbackState ) {
		case MPMusicPlaybackStateStopped:
			[_player stop];
		case MPMusicPlaybackStatePaused:
			[_playPause setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
			[_pollElapsedTime invalidate];
			_pollElapsedTime = nil;
			break;
		case MPMusicPlaybackStatePlaying:
			[_playPause setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
			[_pollElapsedTime invalidate];
			_pollElapsedTime = nil;
			_pollElapsedTime = [NSTimer scheduledTimerWithTimeInterval:1.0f
																target:self
															  selector:@selector(updatePlaybackTime)
															  userInfo:nil
															   repeats:YES];
			break;
		default:
			break;
	}
}

- (void)volumeDidChange:(id)sender
{
	_volumeSlider.value = _player.volume;
}

- (void)refreshColors
{
#warning animate this change? Animate the change of album art (if it changes), too?
	UIColor *keyColor = [_iv.image keyColorToContrastAgainstColors:@[[UIColor whiteColor]]
													  withContrast:UIColorContrastLevelLow];
	
	if ( keyColor ) {
		[[UIApplication sharedApplication] keyWindow].tintColor = keyColor;
		_trackSlider.tintColor = keyColor;
		_volumeSlider.tintColor = keyColor;
	} else {
#warning is there a better way to only run this if keyColor is nil?
		UIColor *bg = [_iv.image backgroundColorToContrastAgainstColors:@[[UIColor whiteColor],
																	      [UIColor lightGrayColor]]
														   withContrast:UIColorContrastLevelLow];
		// Default to dark gray color for sliders
		if ( !bg ) {
			bg = [UIColor neueDarkGray];
		}
		
		[[UIApplication sharedApplication] keyWindow].tintColor = [UIColor neueBlue];
		_trackSlider.tintColor = bg;
		_volumeSlider.tintColor = bg;
	}
}

- (IBAction)playPause:(id)sender
{
	if ( _player.playbackState == MPMusicPlaybackStatePlaying ) {
        [_player pause];
    } else {
        [_player play];
    }
}

- (IBAction)skip:(id)sender
{
	[_player skipToNextItem];
}

- (IBAction)fastForward:(UILongPressGestureRecognizer *)sender
{
#warning this should behave differently if paused
	switch (sender.state) {
		case UIGestureRecognizerStateBegan:
			[_player beginSeekingForward];
			break;
		case UIGestureRecognizerStateEnded:
			[_player endSeeking];
			break;
		default:
			break;
	}
}

- (IBAction)previous:(id)sender
{
#warning go to previous item if in the first few seconds of playback else, go to beginning of song
	[_player skipToPreviousItem];
}

- (IBAction)rewind:(UILongPressGestureRecognizer *)sender
{
#warning this should behave differently if paused
	switch (sender.state) {
		case UIGestureRecognizerStateBegan:
			[_player beginSeekingBackward];
			break;
		case UIGestureRecognizerStateEnded:
			[_player endSeeking];
			break;
		default:
			break;
	}
}

- (IBAction)trackSliderDidBegin:(id)sender
{
	// Stop timer
	[_pollElapsedTime invalidate];
	_pollElapsedTime = nil;
}

- (IBAction)trackSliderDidEnd:(id)sender
{
	// Start timer back up
	[_pollElapsedTime invalidate];
	_pollElapsedTime = nil;
	_pollElapsedTime = [NSTimer scheduledTimerWithTimeInterval:1.0f
														target:self
													  selector:@selector(updatePlaybackTimeWithAnimation)
													  userInfo:nil
													   repeats:YES];
}

- (IBAction)trackSliderChangedValue:(id)sender
{
	[self updatePlaybackTimeForTime:_trackSlider.value withAnimation:NO];
	_player.currentPlaybackTime = _trackSlider.value;
}

- (IBAction)volumeChanged:(id)sender
{
	_player.volume = _volumeSlider.value;
}

- (IBAction)didTapRightBarButtonItem:(id)sender
{
	/*
	 // Testing showing an action sheet to test tintColor change of items on screen.
	 UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@""
	 delegate:Nil
	 cancelButtonTitle:@"Cancel"
	 destructiveButtonTitle:nil
	 otherButtonTitles:nil];
	 [as showFromBarButtonItem:sender animated:YES];
	 */
	
	[self presentViewController:_mediaPicker
					   animated:YES
					 completion:^{}];
}


#pragma mark Media Picker

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker
  didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection
{
    if ( mediaItemCollection ) {
        [_player setQueueWithItemCollection:mediaItemCollection];
        [_player play];
    }
	[mediaPicker dismissViewControllerAnimated:YES
									completion:^{}];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker
{
	[mediaPicker dismissViewControllerAnimated:YES
									completion:^{}];
}


#pragma mark View Controller end

- (void)dealloc
{
#warning unregister notifications?
	[_player endGeneratingPlaybackNotifications];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
