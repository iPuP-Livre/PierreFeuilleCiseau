//
//  ViewController.h
//  PierreFeuilleCiseau
//
//  Created by Marian PAUL on 10/03/12.
//  Copyright (c) 2012 iPuP SARL. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>

// définition des états possibles du jeu !
typedef enum {
    kRock,
    kPaper,
    kScissor
} GameAction;

// définition de qui est serveur et qui est client
typedef enum {
    kServer,
    kClient
} GameNetwork;

// les différents états nécessaires
typedef enum {
    NETWORK_COINTOSS,    // Pour décider qui va être le serveur
    NETWORK_SEND_START_SIGNAL, // On envoie ce paquet pour commencer le compte à rebours
    NETWORK_SEND_ACTION, // On envoie pierre, feuille ou ciseau
    NETWORK_RESULT // on envoie le résultat du jeu    
} PacketCodes;

// cas possibles pour gagner, perdre, ou égalité
typedef enum {
    kWin,
    kLose,
    kEquality
} ResultStatus;

@interface ViewController : UIViewController <GKPeerPickerControllerDelegate, GKSessionDelegate>
{
    // bouton pour la connexion / déconnexion
    UIButton *_buttonConnectDisconnect;
    
    // déclaration du picker pour se connecter au BT
    GKPeerPickerController *_btPicker;
    // déclaration de la session BT
    GKSession *_currentSession;
    
    NSString *_gamePeerId;
    
    UIButton *_buttonStartGame;
    // Label pour notifier si l'utilisateur est serveur ou client
    UILabel *_labelServerOrClient; 
    // label décompte
    UILabel *_labelCountDown;
    
    NSUInteger _gameUniqueID;
    NSInteger _peerStatus;
    
    int _currentCountDown;
    int _myGameAction;
}

@end
