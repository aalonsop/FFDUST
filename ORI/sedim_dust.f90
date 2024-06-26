!ORILAM_LIC Copyright 2006-2022 CNRS, Meteo-France and Universite Paul Sabatier
!ORILAM_LIC This is part of the ORILAM software governed by the CeCILL-C licence
!ORILAM_LIC version 1. See LICENSE, CeCILL-C_V1-en.txt and CeCILL-C_V1-fr.txt
!ORILAM_LIC for details.
!-----------------------------------------------------------------
!!   ##############################
     MODULE MODI_SEDIM_DUST
!!   ##############################
!!
INTERFACE
!
SUBROUTINE SEDIM_DUST(  &
     PTHT               & !I [K] theta
     ,PDTMONITOR        & !I Time step
     ,PRHODREF          & !I [kg/m3] air density
     ,PPABST            & !I [Pa] pressure
     ,PZZ               & !I [m] height of layers
     ,PSVT              & !IO [scalar variable, ppv] dust  concentration
     )

IMPLICIT NONE

REAL,  INTENT(IN) :: PDTMONITOR
REAL,  DIMENSION(:,:,:,:),  INTENT(INOUT) :: PSVT   !scalar variable 
REAL,  DIMENSION(:,:,:),    INTENT(IN)    :: PTHT,PRHODREF, PZZ
REAL,  DIMENSION(:,:,:),    INTENT(IN)    :: PPABST


END SUBROUTINE SEDIM_DUST
!!
END INTERFACE
!!
END MODULE MODI_SEDIM_DUST
!!
!!   #######################################
     SUBROUTINE SEDIM_DUST(PTHT,PDTMONITOR,&
                       PRHODREF,PPABST,PZZ,PSVT)
!!   #######################################
!!
!!   PURPOSE
!!   -------
!!
!!   REFERENCE
!!   ---------
!!   none
!!
!!   AUTHOR
!!    ------
!!    Pierre TULET (GMEI) 
!!
!!   MODIFICATIONS
!!    -------------
!!   Original
!  P. Wautelet 26/04/2019: replace non-standard FLOAT function by REAL function
!
! Entry variables:
!
! PSVTS(INOUT)       -Array of moments included in PSVTS
!
!*************************************************************
! Exit variables:
!
!*************************************************************
! Variables used during the deposition velocity calculation
! 
! ZVGK       -Polydisperse settling velocity of the kth moment (m/s)
!************************************************************
!!
!!   IMPLICIT ARGUMENTS
!
USE MODD_DUST
USE MODD_CSTS_DUST
USE MODI_DUST_VELGRAV
USE MODE_DUST_PSD
!
!
IMPLICIT NONE
!
!*      0.1    declarations of arguments
!
REAL,  INTENT(IN) :: PDTMONITOR
REAL,  DIMENSION(:,:,:,:),  INTENT(INOUT)    :: PSVT  !scalar variable 
REAL,  DIMENSION(:,:,:),    INTENT(IN)    :: PTHT,PRHODREF, PZZ
REAL,  DIMENSION(:,:,:),    INTENT(IN)    :: PPABST
!
!*      0.2    declarations of local variables
!
INTEGER :: JK, JN, JT
INTEGER :: IMODEIDX
INTEGER :: ISPLITA
REAL    :: ZTSPLITR
REAL,    DIMENSION(NMODE_DST*3) :: ZPMIN
REAL,    DIMENSION(NMODE_DST)   :: ZINIRADIUS
REAL :: ZRGMIN, ZSIGMIN
REAL,  DIMENSION(SIZE(PSVT,1),SIZE(PSVT,2),SIZE(PSVT,3),NMODE_DST)   :: ZRG, ZSIG, ZDPG
REAL,  DIMENSION(SIZE(PSVT,1),SIZE(PSVT,2),SIZE(PSVT,3),3*NMODE_DST) :: ZPM, ZPMOLD
REAL,  DIMENSION(SIZE(PSVT,1),SIZE(PSVT,2),SIZE(PSVT,3)+1,3*NMODE_DST) :: ZFLUXSED, ZFLUXMAX
REAL,  DIMENSION(SIZE(PSVT,1),SIZE(PSVT,2),SIZE(PSVT,3)) :: ZH,ZMU, ZW, ZVSNUMMAX
REAL,  DIMENSION(SIZE(PSVT,1),SIZE(PSVT,2),SIZE(PSVT,3),3*NMODE_DST) :: ZVGK, ZDPK
REAL,  DIMENSION(SIZE(PSVT,1),SIZE(PSVT,2),SIZE(PSVT,3),NMODE_DST)   :: ZVG
REAL :: ZVSMAX, ZHMIN, ZRHOI, ZFAC
INTEGER             :: ILU  ! indice K End       in z direction
INTEGER,DIMENSION(NMODE_DST) :: NM0, NM3, NM6
REAL                :: ZDEN2MOL, ZAVOGADRO, ZMD, ZMI 
LOGICAL, SAVE       :: LSEDFIX = .TRUE.
!
!*       0.3   initialize constant
!
ZRHOI = XDENSITY_DUST

ZMU(:,:,:)     = 0.
ZH(:,:,:)      = 0.
ZVGK(:,:,:,:)  = 0.
ZVG(:,:,:,:)   = 0.
ZDPK(:,:,:,:)  = 0.
ZW(:,:,:)      = 0.
ZFLUXSED(:,:,:,:) = 0.
ILU = SIZE(PSVT,3)
ZFAC  = (4./3.)*XPI*ZRHOI*1.e-9
ZAVOGADRO = 6.0221367E+23
ZMD = 28.9644E-3
ZDEN2MOL = 1E-6 * ZAVOGADRO  / ZMD
ZMI   = XMOLARWEIGHT_DUST ! molecular mass in kg/mol
!
!*       1.   compute dimensions of arrays
!
DO JN=1,NMODE_DST
  IMODEIDX = JPDUSTORDER(JN)
  !Calculations here are for one mode only
  IF (CRGUNITD=="MASS") THEN
    ZINIRADIUS(JN) = XINIRADIUS(IMODEIDX) * EXP(-3.*(LOG(XINISIG(IMODEIDX)))**2)
  ELSE
    ZINIRADIUS(JN) = XINIRADIUS(IMODEIDX)
  END IF

  !Set counter for number, M3 and M6
  NM0(JN) = 1+(JN-1)*3
  NM3(JN) = 2+(JN-1)*3
  NM6(JN) = 3+(JN-1)*3
  !Get minimum values possible
  ZPMIN(NM0(JN)) = XN0MIN(IMODEIDX)
  ZRGMIN     = ZINIRADIUS(JN)
  IF (LVARSIG) THEN
    ZSIGMIN = XSIGMIN
  ELSE
    ZSIGMIN = XINISIG(IMODEIDX)
  ENDIF
  ZPMIN(NM3(JN)) = XN0MIN(IMODEIDX) * (ZRGMIN**3)*EXP(4.5 * LOG(ZSIGMIN)**2) 
  ZPMIN(NM6(JN)) = XN0MIN(IMODEIDX) * (ZRGMIN**6)*EXP(18. * LOG(ZSIGMIN)**2)
END DO
!
!*       2.   compute SIG, RG and moments
!
CALL PPP2DUST(PSVT, PRHODREF, PSIG3D=ZSIG, PRG3D=ZRG, PM3D=ZPM)

ZPMOLD(:,:,:,:)=ZPM(:,:,:,:)
!
!*       3.   compute gravitational velocities
!
CALL DUST_VELGRAV(ZSIG(:,:,1:ILU,:), ZRG(:,:,1:ILU,:),    &
                      PTHT(:,:,1:ILU),  PPABST(:,:,1:ILU),&
                      PRHODREF(:,:,1:ILU), ZRHOI,         &
                      ZMU(:,:,1:ILU), ZVGK(:,:,1:ILU,:),  &
                      ZDPK(:,:,1:ILU,:),ZVG(:,:,1:ILU,:), &
                      ZDPG(:,:,1:ILU,:))
!
!*       4.   Compute time-splitting condition
!
ZH=9999.
ZVSNUMMAX(:,:,:)   = 0.
ZFLUXSED(:,:,:,:) = 0.

DO JK=1,ILU
   ZH(:,:,JK)=PZZ(:,:,JK+1)-PZZ(:,:,JK)
   ! Maximum velocity
   ZVSNUMMAX(:,:,JK) = ZH(:,:,JK) / PDTMONITOR
ENDDO
!
ZHMIN=MINVAL(ZH(:,:,1:ILU))

!Get loss rate [1/s] instead of [m/s]
DO JN=1,NMODE_DST

  ZVSMAX=MAXVAL(ZVGK(:,:,1:ILU,NM0(JN)))
  ISPLITA = INT(ZVSMAX*PDTMONITOR/ZHMIN)+1
  ZTSPLITR  = PDTMONITOR / REAL(ISPLITA)
  ZFLUXSED(:,:,ILU+1,NM0(JN)) = 0.

  DO JT=1,ISPLITA
    ZFLUXSED(:,:,1:ILU,NM0(JN))= ZVGK(:,:,1:ILU,NM0(JN))* ZPM(:,:,1:ILU,NM0(JN))
    DO JK=1,ILU
    ZW(:,:,JK)  = ZTSPLITR /(PZZ(:,:,JK+1)-PZZ(:,:,JK))
    ZPM(:,:,JK,NM0(JN))= ZPM(:,:,JK,NM0(JN)) + &
                      ZW(:,:,JK)*(ZFLUXSED(:,:,JK+1,NM0(JN))- ZFLUXSED(:,:,JK,NM0(JN)))
    END DO
  ENDDO
   ZPM(:,:,:,NM3(JN)) = ZPM(:,:,:,NM0(JN)) *&
                        (ZRG(:,:,:,JN)**3)*EXP(4.5 * LOG(ZSIG(:,:,:,JN))**2)
   ZPM(:,:,:,NM6(JN)) = ZPM(:,:,:,NM0(JN)) *&
                        (ZRG(:,:,:,JN)**6)*EXP(18. * LOG(ZSIG(:,:,:,JN))**2)
  
ENDDO

!
!*       5.   Return to concentration in ppv (#/molec_{air})
!
DO JN=1,NMODE_DST
IF (LVARSIG) THEN
WHERE ((ZPM(:,:,:,NM0(JN)) .GT. 10.*ZPMIN(NM0(JN))).AND.&
       (ZPM(:,:,:,NM3(JN)) .GT. 10.*ZPMIN(NM3(JN))).AND.&
       (ZPM(:,:,:,NM6(JN)) .GT. 10.*ZPMIN(NM6(JN))))
  PSVT(:,:,:,1+(JN-1)*3) = ZPM(:,:,:,NM0(JN)) * XMD / &
                           (XAVOGADRO*PRHODREF(:,:,:))
  PSVT(:,:,:,2+(JN-1)*3) = ZPM(:,:,:,NM3(JN)) * XMD*XPI * 4./3.*ZRHOI  / &
                           (ZMI*PRHODREF(:,:,:)*XM3TOUM3)
  PSVT(:,:,:,3+(JN-1)*3) = ZPM(:,:,:,NM6(JN)) * XMD / &
                           (XAVOGADRO*PRHODREF(:,:,:)*1.d-6)
ELSEWHERE
  PSVT(:,:,:,1+(JN-1)*3) = ZPMOLD(:,:,:,NM0(JN)) * XMD / &
                           (XAVOGADRO*PRHODREF(:,:,:))
  PSVT(:,:,:,2+(JN-1)*3) = ZPMOLD(:,:,:,NM3(JN)) * XMD*XPI * 4./3.*ZRHOI  / &
                           (ZMI*PRHODREF(:,:,:)*XM3TOUM3)
  PSVT(:,:,:,3+(JN-1)*3) = ZPMOLD(:,:,:,NM6(JN)) * XMD / &
                           (XAVOGADRO*PRHODREF(:,:,:)*1.d-6)
ENDWHERE
ELSE IF (LRGFIX_DST) THEN

WHERE ((ZPM(:,:,:,NM3(JN)) .GT. 10*ZPMIN(NM3(JN))))
  PSVT(:,:,:,JN)         = ZPM(:,:,:,NM3(JN)) * XMD*XPI * 4./3.*ZRHOI  / &
                           (ZMI*PRHODREF(:,:,:)*XM3TOUM3)
ELSEWHERE
  PSVT(:,:,:,JN)         = ZPMOLD(:,:,:,NM3(JN)) * XMD*XPI * 4./3.*ZRHOI  / &
                           (ZMI*PRHODREF(:,:,:)*XM3TOUM3)
ENDWHERE

ELSE

WHERE ((ZPM(:,:,:,NM0(JN)) .GT. 10*ZPMIN(NM0(JN))).AND.&
       (ZPM(:,:,:,NM3(JN)) .GT. 10*ZPMIN(NM3(JN))))
  PSVT(:,:,:,1+(JN-1)*2) = ZPM(:,:,:,NM0(JN)) * XMD / &
                           (XAVOGADRO*PRHODREF(:,:,:))
  PSVT(:,:,:,2+(JN-1)*2) = ZPM(:,:,:,NM3(JN)) * XMD*XPI * 4./3.*ZRHOI  / &
                           (ZMI*PRHODREF(:,:,:)*XM3TOUM3)
ELSEWHERE
  PSVT(:,:,:,1+(JN-1)*2) = ZPMOLD(:,:,:,NM0(JN)) * XMD / &
                           (XAVOGADRO*PRHODREF(:,:,:))
  PSVT(:,:,:,2+(JN-1)*2) = ZPMOLD(:,:,:,NM3(JN)) * XMD*XPI * 4./3.*ZRHOI  / &
                           (ZMI*PRHODREF(:,:,:)*XM3TOUM3)
ENDWHERE

END IF
ENDDO
!
END SUBROUTINE SEDIM_DUST
