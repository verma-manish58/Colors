//
//  MTZViewController.m
//  Colors
//
//  Created by Matt Zanchelli on 9/2/13.
//  Copyright (c) 2013 Matt Zanchelli. All rights reserved.
//

#import "MTZViewController.h"

#import <MediaPlayer/MediaPlayer.h>

#import "UIColor+Components.h"
#import "UIColor+Hex.h"
#import "UIColor+Manipulation.h"
#import "UIColor+NeueColors.h"
#import "UIImage+Colors.h"
#import "UIImage+Crop.h"

#import "MTZSlider.h"

#define DEBUG_MODE 0

@interface MTZViewController ()

@property (strong, nonatomic) MPMusicPlayerController *player;
@property (strong, nonatomic) IBOutlet UIImageView *iv;

@property (strong, nonatomic) IBOutlet MTZSlider *trackSlider;
@property (strong, nonatomic) IBOutlet MTZSlider *volumeSlider;

@property (strong, nonatomic) IBOutlet UILabel *trackTitle;
@property (strong, nonatomic) IBOutlet UILabel *artistAndAlbumTitles;

@property (strong, nonatomic) UILabel *trackNumbersLabel;

@property (strong, nonatomic) IBOutlet UINavigationBar *navigationBar;

@property (strong, nonatomic) IBOutlet UIImageView *topShadow;
@property (strong, nonatomic) IBOutlet UIImageView *bottomShadow;

@property (strong, nonatomic) IBOutlet UILabel *timeElapsed;
@property (strong, nonatomic) IBOutlet UILabel *timeRemaining;

@property (strong, nonatomic) IBOutlet UIButton *playPause;

#if DEBUG_MODE
@property (strong, nonatomic) UIImageView *imgv;
#endif

@end

@implementation MTZViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	[self.view setTintAdjustmentMode:UIViewTintAdjustmentModeAutomatic];
	
	_trackSlider.fillImage = [UIImage imageNamed:@"ProgressFill"];
	_trackSlider.trackImage = [UIImage imageNamed:@"ProgressTrack"];
	[_trackSlider setThumbImage:[UIImage imageNamed:@"ProgressThumb"]
					   forState:UIControlStateNormal];
	
	_volumeSlider.value = _player.volume;
	_volumeSlider.fillImage = [UIImage imageNamed:@"VolumeFill"];
	_volumeSlider.trackImage = [UIImage imageNamed:@"VolumeTrack"];
	[_volumeSlider setThumbImage:[UIImage imageNamed:@"VolumeThumb"]
						forState:UIControlStateNormal];
	
	UIInterpolatingMotionEffect *verticalMotion = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
	verticalMotion.minimumRelativeValue = @2;
	verticalMotion.maximumRelativeValue = @-2;
	_topShadow.motionEffects = @[verticalMotion];
	_bottomShadow.motionEffects = @[verticalMotion];
	
	_trackNumbersLabel = [[UILabel alloc] initWithFrame:(CGRect){0,0,160,32}];
	_trackNumbersLabel.textAlignment = NSTextAlignmentCenter;
	_trackNumbersLabel.text = @"1 of 16";
	self.navigationBar.topItem.titleView = _trackNumbersLabel;
	[self.navigationBar.topItem setHidesBackButton:NO animated:NO];
	
	_player = [MPMusicPlayerController iPodMusicPlayer];
	
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
	
#if DEBUG_MODE
	_imgv = [[UIImageView alloc] initWithFrame:(CGRect){0,20,64,64}];
	[self.view addSubview:_imgv];
#endif
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
	
#if DEBUG_MODE
	_imgv.image = [albumArtwork scaleToSize:(CGSize){64,64}
				   withInterpolationQuality:kCGInterpolationLow];
#endif
	
	_trackTitle.text = [currentItem valueForProperty:MPMediaItemPropertyTitle];
	NSString *artist = [currentItem valueForProperty:MPMediaItemPropertyArtist];
	NSString *album = [currentItem valueForProperty:MPMediaItemPropertyAlbumTitle];
	_artistAndAlbumTitles.text = [NSString stringWithFormat:@"%@ - %@", artist, album];
	
	NSString *trackNo = [NSString stringWithFormat:@"%@", [currentItem valueForProperty:MPMediaItemPropertyAlbumTrackNumber]];
	NSString *trackOf = [NSString stringWithFormat:@"%@", [currentItem valueForProperty:MPMediaItemPropertyAlbumTrackCount]];
	NSString *title = [NSString stringWithFormat:@"%@ of %@", trackNo, trackOf];
	NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:title];
	[attributedTitle addAttribute:NSFontAttributeName
							value:[UIFont boldSystemFontOfSize:15.0f]
							range:NSMakeRange(0, trackNo.length)];
	[attributedTitle addAttribute:NSFontAttributeName
							value:[UIFont systemFontOfSize:15.0f]
							range:NSMakeRange(trackNo.length, 4)];
	[attributedTitle addAttribute:NSFontAttributeName
							value:[UIFont boldSystemFontOfSize:15.0f]
							range:NSMakeRange(trackNo.length + 4, trackOf.length)];
	_trackNumbersLabel.attributedText = attributedTitle;
	
	CGFloat minutes, seconds;
	
	/*
	MPNowPlayingInfoCenter *nowPlaying = [MPNowPlayingInfoCenter defaultCenter];
	NSNumber *playbackElapsed = [[nowPlaying nowPlayingInfo] valueForKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
	
	double elapsed = playbackElapsed.doubleValue;
	float minutes = floor(elapsed / 60 );
	float seconds = round(elapsed - minutes * 60);
	_timeElapsed.text = [NSString stringWithFormat:@"%.0f:%.0f", minutes, seconds];
	 */
	
	double elapsed = 0.0f;
	
	NSNumber *playbackDuration = [currentItem valueForProperty:MPMediaItemPropertyPlaybackDuration];
	NSTimeInterval duration = playbackDuration.doubleValue;
	NSTimeInterval remaining = duration - elapsed;
	minutes = floor(remaining / 60);
	seconds = round(remaining - minutes * 60);
	NSString *secondsString;
	
	if ( seconds < 10 ) {
		secondsString = [NSString stringWithFormat:@"0%.0f", seconds];
	} else {
		secondsString = [NSString stringWithFormat:@"%.0f", seconds];
	}
	
	_timeRemaining.text = [NSString stringWithFormat:@"-%.0f:%@", minutes, secondsString];
}

- (void)playbackStateDidChange:(id)sender
{
	switch ( _player.playbackState ) {
		case MPMusicPlaybackStatePlaying:
			[_playPause setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
			break;
		case MPMusicPlaybackStateStopped:
			[_player stop];
		case MPMusicPlaybackStatePaused:
			[_playPause setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
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
	UIColor *bg = [_iv.image keyColor];
	if ( !bg ) {
		bg = [UIColor blackColor];
	}
	self.view.tintColor = bg;
}

- (IBAction)playPause:(id)sender
{
	if ( _player.playbackState == MPMusicPlaybackStatePlaying ) {
        [_player pause];
    } else {
        [_player play];
    }
}

- (IBAction)fastForward:(id)sender
{
	[_player skipToNextItem];
}

- (IBAction)rewind:(id)sender
{
#warning go to previous item if in the first few seconds of playback else, go to beginning of song
	[_player skipToPreviousItem];
}

- (IBAction)volumeChanged:(id)sender
{
	_player.volume = _volumeSlider.value;
}

- (IBAction)didTapRightBarButtonItem:(id)sender
{
	// Showing an action sheet to test tintColor change of items on screen.
	UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@""
													delegate:Nil
										   cancelButtonTitle:@"Cancel"
									  destructiveButtonTitle:nil
										   otherButtonTitles:nil];
	[as showFromBarButtonItem:sender animated:YES];
}

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
