#ifndef RAZER_PROTOCOL_H
#define RAZER_PROTOCOL_H

#import <Foundation/Foundation.h>

#define RAZER_VENDOR_ID                0x1532
#define RAZER_PID_DEATHADDER_ESS_2021  0x0098
#define RAZER_PID_DEATHADDER_ESS_2018  0x006E
#define RAZER_PID_DEATHADDER_ESS_WHITE 0x0071

#define RAZER_REPORT_LEN               90

#define RAZER_STATUS_NEW               0x00
#define RAZER_STATUS_BUSY              0x01
#define RAZER_STATUS_SUCCESS           0x02
#define RAZER_STATUS_FAILURE           0x03
#define RAZER_STATUS_TIMEOUT           0x04
#define RAZER_STATUS_NOT_SUPPORTED     0x05

#define RAZER_VARSTORE                 0x01

#define RAZER_CMD_CLASS_DPI            0x04
#define RAZER_CMD_DPI_SET              0x05
#define RAZER_CMD_DPI_GET              0x85

#define RAZER_CMD_CLASS_MATRIX         0x0F
#define RAZER_CMD_MATRIX_EFFECT        0x02
#define RAZER_CMD_MATRIX_BRIGHTNESS    0x04

#define RAZER_LED_ZERO                 0x00
#define RAZER_LED_SCROLL               0x01
#define RAZER_LED_LOGO                 0x04

typedef NS_ENUM(NSInteger, RazerLightEffect) {
    RazerLightEffectOff       = 0,
    RazerLightEffectStatic    = 1,
    RazerLightEffectBreathing = 2
};

static inline uint8_t razer_calculate_checksum(const uint8_t *buf) {
    uint8_t c = 0;
    for (int i = 2; i < 88; i++) {
        c ^= buf[i];
    }
    return c;
}

#endif /* RAZER_PROTOCOL_H */
