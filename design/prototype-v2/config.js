/* TODO(PROTO-01): Proposed design defaults; tune on physical touch / TV devices. */
window.PROTO_CONFIG = Object.freeze({pressMs:90,releaseMs:160,cardMs:180,panelMs:260,hudHideMs:3600,simulationMs:900,toastMs:2600,pressScale:.97,cardRadius:14,panelRadius:24,defaultTheme:'dark',defaultService:'Jellyfin',defaultView:'desktop',defaultSpeed:1,defaultDanmakuOpacity:70,defaultDanmakuDensity:45});
/* TODO(PROTO-RATING-01): Existing policy limits; fixture values are illustrative only.
   TODO(PROTO-NAV-01): Retained floating touch navigation dimensions, tune on devices. */
window.RATING_CONFIG = Object.freeze({
 detailLimit:4,heroLimit:2,personalMin:.5,personalMax:10,personalStep:.5,personalInitial:8,
 defaultOrder:['rottenTomatoesCritic','rottenTomatoesAudience','imdb','tmdb','critic','audience','other'],
 fixtures:{Plex:[{source:'rottenTomatoesCritic',value:9.2},{source:'rottenTomatoesAudience',value:8.8},{source:'imdb',value:8.7},{source:'tmdb',value:8.4},{source:'other',value:8.1}],Jellyfin:[{source:'critic',value:8.2},{source:'audience',value:8.7}],Emby:[{source:'critic',value:8.1},{source:'audience',value:8.6}]},
 serviceCounts:{Plex:4,Jellyfin:2,Emby:2},
 navWidth:336,navHeight:58,navBottom:18,navBlur:28
});
/* TODO(PROTO-PLAYER-01..06): V4 behavior retained; gesture/feedback defaults need physical-device tuning. */
window.PLAYER_CONFIG = Object.freeze({durationSeconds:7680,touchHudMs:5000,mouseHudMs:3000,doubleTapMs:240,doubleTapDistance:32,repeatSeekMs:800,seekStepSeconds:10,timelineKeyStepSeconds:5,gestureThreshold:8,longPressMs:450,temporarySpeed:2,feedbackMs:650,seekDragFraction:.35,verticalGain:1.5,heatLongPressMs:450,heatThreshold:.6,heatSnapBuckets:6,heatBuckets:100,heatPeaks:[{at:.12,height:.58,width:.028},{at:.28,height:.92,width:.035},{at:.51,height:.7,width:.045},{at:.7,height:.98,width:.03},{at:.86,height:.78,width:.035}],heatMaxCount:160,bufferedPercent:68,introEndPercent:4,outroStartPercent:96,popoverWidth:280,popoverGap:12,popoverMs:160,drawerMs:240,switchMs:450,brightnessMin:0,brightnessMax:100,volumeMin:0,volumeMax:100,defaultSubtitleSize:22,defaultSubtitlePosition:18,defaultGain:0,defaultAudioDelay:0,defaultChannel:'原始声道',defaultZoom:100,defaultSleep:'关闭',defaultSameScreen:40});
