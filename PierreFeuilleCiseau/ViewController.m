//
//  ViewController.m
//  PierreFeuilleCiseau
//
//  Created by Marian PAUL on 10/03/12.
//  Copyright (c) 2012 iPuP SARL. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

#define kRockPaperScissorSessionID @"rockPaperScissor" // l'id de la session
#define kMaxPacketSize 1024 // on réserve un peu plus. Cela correspond à la limite conseillée pour la taille d'un paquet
#define kStartCounter 5 // on a 5 secondes pour choisir

@interface ViewController ()
- (void) decrementCount:(NSTimer*)timer;
- (void) sendNetworkPacket:(GKSession *)session packetID:(int)packetID withData:(void *)data ofLength:(int)length reliable:(BOOL)howtosend;
- (void) receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context;
- (void) performResultWithClientAction:(int)clientAction;
- (void) displayResultForClientResult:(int)clientResult;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Bouton de connexion / déconnexion
    _buttonConnectDisconnect = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_buttonConnectDisconnect addTarget:self action:@selector(connectToBluetooth:) forControlEvents:UIControlEventTouchUpInside];
    [_buttonConnectDisconnect setTitle:@"Connexion" forState:UIControlStateNormal];
    [_buttonConnectDisconnect setTitle:@"Déconnexion" forState:UIControlStateSelected];
    [_buttonConnectDisconnect setFrame:CGRectMake(30, 30, 260, 30)];
    [self.view addSubview:_buttonConnectDisconnect];
    
    // bouton pour commencer le jeu 
    _buttonStartGame = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_buttonStartGame addTarget:self action:@selector(startGame:) forControlEvents:UIControlEventTouchUpInside];
    [_buttonStartGame setTitle:@"Commencer" forState:UIControlStateNormal];
    [_buttonStartGame setFrame:CGRectMake(60, 70, 200, 30)];
    // initialement on cache le bouton
    _buttonStartGame.hidden = YES;
    [self.view addSubview:_buttonStartGame];
    
    // Label pour spécifier le statut (serveur ou client)
    _labelServerOrClient = [[UILabel alloc] initWithFrame:CGRectMake(60, 110, 200, 30)];
    _labelServerOrClient.textAlignment = UITextAlignmentCenter;
    _labelServerOrClient.backgroundColor = [UIColor clearColor];
    _labelServerOrClient.text = @"Connectez-vous";
    [self.view addSubview:_labelServerOrClient];
    
    // Bouton feuille
    UIButton *buttonPaper = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [buttonPaper addTarget:self action:@selector(gameAction:) forControlEvents:UIControlEventTouchUpInside];
    [buttonPaper setFrame:CGRectMake(60, 190, 200, 30)];
    [buttonPaper setTitle:@"Feuille" forState:UIControlStateNormal];
    // on utilise le tag pour savoir à quoi correspond le bouton
    [buttonPaper setTag:kPaper];
    [self.view addSubview:buttonPaper];
    
    // Bouton pierre
    UIButton *buttonRock = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [buttonRock addTarget:self action:@selector(gameAction:) forControlEvents:UIControlEventTouchUpInside];
    [buttonRock setFrame:CGRectMake(60, 230, 200, 30)];
    [buttonRock setTitle:@"Pierre" forState:UIControlStateNormal];
    // on utilise le tag pour savoir à quoi correspond le bouton
    [buttonRock setTag:kRock];
    [self.view addSubview:buttonRock];
    
    // Bouton Ciseau
    UIButton *buttonScissor = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [buttonScissor addTarget:self action:@selector(gameAction:) forControlEvents:UIControlEventTouchUpInside];
    [buttonScissor setFrame:CGRectMake(60, 270, 200, 30)];
    [buttonScissor setTitle:@"Ciseau" forState:UIControlStateNormal];
    // on utilise le tag pour savoir à quoi correspond le bouton
    [buttonScissor setTag:kScissor];
    [self.view addSubview:buttonScissor];
    
    
    // label décompte
    _labelCountDown = [[UILabel alloc] initWithFrame:CGRectMake(60, 420, 200, 30)];
    _labelCountDown.textAlignment = UITextAlignmentCenter;
    _labelCountDown.backgroundColor = [UIColor clearColor];
    _labelCountDown.text = @"";
    [self.view addSubview:_labelCountDown];
    
    // Sécurité de l'échange
    // on créé un uuid si il n'existe pas encore, et on le sauvegarde
    if(![[NSUserDefaults standardUserDefaults] objectForKey:@"uuid"]){
        CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
        CFStringRef string = CFUUIDCreateString(NULL, theUUID);
        NSString *uuid = (__bridge NSString *)string;
        [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:@"uuid"];
        CFRelease(theUUID);        
    }
    
    _gameUniqueID = [[[NSUserDefaults standardUserDefaults] objectForKey:@"uuid"] hash];


    // on se met par défaut en client
    _peerStatus = kClient;
    
    // on met par défaut feuille comme game action
    _myGameAction = kPaper;

    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) startGame:(id)sender {
    NSLog(@"Start game");
    _currentCountDown = kStartCounter; // [1]
    
    if (_peerStatus == kServer) {
        // si on est serveur, on envoie le signal de départ et on commence le décompte
        [self sendNetworkPacket:_currentSession packetID:NETWORK_SEND_START_SIGNAL withData:(__bridge void*)[NSDate date] ofLength:class_getInstanceSize([NSDate class]) reliable:YES]; // [2]
        [self decrementCount:nil]; // [3]
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(decrementCount:) userInfo:nil repeats:YES]; // [4]
    }
    // sinon, on ne fait rien et on attend le signal de départ dans la méthode de réception des données
}

- (void) gameAction:(id)sender {
    UIButton *buttonSender = (UIButton*)sender;
    // on récupère l'action depuis le tag du bouton
    _myGameAction = buttonSender.tag;
}

#pragma mark - Bluetooth Manager

-(void) connectToBluetooth :(id) sender 
{
    
    UIButton *buttonSender = (UIButton*)sender;
    // on pourrait aussi récupérer à partir de buttonConnectDisconnect
    
    BOOL wantToDisconnect = buttonSender.selected;
    if (wantToDisconnect)
    {        
        // on se déconnecte
        [_currentSession disconnectFromAllPeers];
        // on libère la session
        _currentSession = nil;
    }
    else 
    {
        // déclaration du picker
        _btPicker = [[GKPeerPickerController alloc] init];
        // self est delegate
        _btPicker.delegate = self; // [1]
        // GKPeerPickerConnectionTypeOnline : une connexion depuis Internet
        // GKPeerPickerConnectionTypeNearby : une connexion locale depuis le bluetooth
        _btPicker.connectionTypesMask = GKPeerPickerConnectionTypeNearby;    // [2]   
        
        // on affiche le picker
        [_btPicker show];         
    }
    
    // on change l'état du bouton
    buttonSender.selected = !buttonSender.selected;
}

#pragma mark - Bluetooth delegate

// la connexion est établie 
- (void)peerPickerController:(GKPeerPickerController *)picker didConnectPeer:(NSString *)peerID toSession:(GKSession *) session 
{
    // on récupère le peerId de la personne connectée
    _gamePeerId = peerID; // [1]
    // on récupère la session
    _currentSession = session;
    // self est délégué de la session
    session.delegate = self; // [2]
    // on met self pour recevoir les données entrantes
    [session setDataReceiveHandler:self withContext:NULL]; // [3]
    // on enlève le delegate du picker
    picker.delegate = nil;
    // on enlève le picker
    [picker dismiss];
    
// on envoie le cointoss pour savoir qui sera client / serveur 
[self sendNetworkPacket:_currentSession packetID:NETWORK_COINTOSS withData:&_gameUniqueID ofLength:sizeof(int) reliable:YES];

}

#pragma mark - Delegate de la session
//appelée lorsque la session change d'état
- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state 
{
    switch (state)
    {
        case GKPeerStateConnected:
            NSLog(@"Connecté");
            break;
        case GKPeerStateDisconnected:
            NSLog(@"Déconnecté");
            // on libère la session en cours
            _currentSession = nil;
            
            // on remet le bouton dans l'état de connexion
            _buttonConnectDisconnect.selected = NO;
            break;
        default:
            break;
    }
}

- (GKSession *)peerPickerController:(GKPeerPickerController *)picker sessionForConnectionType:(GKPeerPickerConnectionType)type 
{ 
    GKSession *session = [[GKSession alloc] initWithSessionID:kRockPaperScissorSessionID displayName:nil sessionMode:GKSessionModePeer]; 
    return session;
}

// la connexion a été annulée
- (void)peerPickerControllerDidCancel:(GKPeerPickerController *)picker
{
    // on enlève le delegate du picker
    picker.delegate = nil;
    
    // on revient au bouton pour la connexion
    _buttonConnectDisconnect.selected = NO;
}

#pragma mark - Envoi réception des paquets

- (void)sendNetworkPacket:(GKSession *)session packetID:(int)packetID withData:(void *)data ofLength:(int)length reliable:(BOOL)howtosend 
{
    // On va construire une trame pour le paquet
    static unsigned char networkPacket[kMaxPacketSize]; // [1]
    // on a un entier pour l'entête : il contient l'id du packet (défini dans packetCodes)
    const unsigned int packetHeaderSize = sizeof(int); // [2]
    // on vérifie bien que la taille du paquet est la bonne, sinon on ignore
    if(length < (kMaxPacketSize - packetHeaderSize)) {
        int *pIntData = (int *)&networkPacket[0];
        // on remplit le header
        pIntData[0] = packetID; // [3]
        // on copie la data à la suite
        memcpy( &networkPacket[packetHeaderSize], data, length ); // [4]
        // on convertit le paquet en objet NSData, nécessaire pour envoyer les données
        NSData *packet = [NSData dataWithBytes: networkPacket length: (length+packetHeaderSize)];
        if(howtosend == YES) { 
            [session sendData:packet toPeers:[NSArray arrayWithObject:_gamePeerId] withDataMode:GKSendDataReliable error:nil]; // [5]
        } else {
            [session sendData:packet toPeers:[NSArray arrayWithObject:_gamePeerId] withDataMode:GKSendDataUnreliable error:nil];
        }
    }
}

- (void)receiveData:(NSData *)data fromPeer:(NSString *)peer inSession:(GKSession *)session context:(void *)context 
{ 
    unsigned char *incomingPacket = (unsigned char *)[data bytes];
    int *pIntData = (int *)&incomingPacket[0];
    
    int packetID = pIntData[0];
    
    switch( packetID ) {
        case NETWORK_COINTOSS:
        {
            // on récupère le coin toss pour savoir qui est serveur client    
            int coinToss = pIntData[1];
            // si le jeton de l'autre est plus grand que le notre, il est serveur...
            if(coinToss > _gameUniqueID) {
                _peerStatus = kClient;
            }
            else {
                _peerStatus = kServer;
            }
            
            // on cache si on est client le bouton pour lancer le décompte
            _buttonStartGame.hidden = (_peerStatus == kClient) ? YES : NO;
            
            // on notifie l'utilisateur si il est serveur ou client
            _labelServerOrClient.text = (_peerStatus == kServer) ? @"Serveur" : @"Client";


        }
            break;
        case NETWORK_SEND_START_SIGNAL:
        {
            _currentCountDown = kStartCounter;
            
            // on a reçu le signal de départ, on commence à décompter
            // on lance une première fois la méthode
            [self decrementCount:nil];
            [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(decrementCount:) userInfo:nil repeats:YES];

        }
            break;
        case NETWORK_SEND_ACTION:
        {
            // on vient de recevoir l'action du client
            int clientAction = pIntData[1];
            [self performResultWithClientAction:clientAction];

        }
            break;
        case NETWORK_RESULT:
        {
            // on vient de recevoir le résultat du serveur
            int clientResult = pIntData[1];
            [self displayResultForClientResult:clientResult];
        }
            break;
        default:
            // erreur
            break;
    }
}

- (void) performResultWithClientAction:(int)clientAction {
    int clientResult;
    
    switch (_myGameAction) {
        case kPaper:
            switch (clientAction) {
                case kPaper:
                    clientResult = kEquality;
                    break;
                case kRock:
                    clientResult = kLose;
                    break;
                case kScissor:
                    clientResult = kWin;
                    break;
                default:
                    break;
            }
            break;
        case kRock:
            switch (clientAction) {
                case kPaper:
                    clientResult = kWin;
                    break;
                case kRock:
                    clientResult = kEquality;
                    break;
                case kScissor:
                    clientResult = kLose;
                    break;
                default:
                    break;
            }
            break;
        case kScissor:
            switch (clientAction) {
                case kPaper:
                    clientResult = kLose;
                    break;
                case kRock:
                    clientResult = kWin;
                    break;
                case kScissor:
                    clientResult = kEquality;
                    break;
                default:
                    break;
            }
            break;
        default:
            break;
    }
    
    // si on est serveur, on avertit le client de sa défaite ou non
    if (_peerStatus == kServer) {
        [self sendNetworkPacket:_currentSession packetID:NETWORK_RESULT withData:&clientResult ofLength:sizeof(int) reliable:YES];
        // on affiche le résultat
        [self displayResultForClientResult:clientResult];
    }

}

- (void) displayResultForClientResult:(int)clientResult 
{
    NSString *resultString;
    
    if (_peerStatus == kClient) {
        switch (clientResult) {
            case kWin:
                resultString = @"gagné";
                break;
            case kLose:
                resultString = @"perdu";
                break;
            case kEquality:
                resultString = @"égalité";
                break;
            default:
                break;
        }
    }
    else 
    {
        switch (clientResult) {
            case kWin:
                resultString = @"perdu";
                break;
            case kLose:
                resultString = @"gagné";
                break;
            case kEquality:
                resultString = @"égalité";
                break;
            default:
                break;
        }
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Résultat"
                                                             message:[NSString stringWithFormat:@"Vous avez %@", resultString]
                                                            delegate:nil 
                                                   cancelButtonTitle:@"Ok"
                                                   otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Timer

- (void) decrementCount:(NSTimer*)theTimer 
{
    _labelCountDown.text = [NSString stringWithFormat:@"%d", _currentCountDown];
    // on décrémente le compteur
    _currentCountDown --;
    
    if (_currentCountDown == 0) 
    {
        [theTimer invalidate];
        theTimer = nil;
        _labelCountDown.text = @"";
        // si on est client, on envoie au serveur mon action
        if (_peerStatus == kClient) {
            [self sendNetworkPacket:_currentSession packetID:NETWORK_SEND_ACTION withData:&_myGameAction ofLength:sizeof(int) reliable:YES];
        }
    } 
}



@end
