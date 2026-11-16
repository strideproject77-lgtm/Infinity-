/*
 * INFINITY's Swift-to-Husk C declaration boundary.
 *
 * This deliberately exposes only Husk's public app-facing translation-layer API.
 * It does not import HuskBridge.h (which pulls in QEMU/JIT pairing dependencies),
 * and it does not claim that the native engine is linked into the app target yet.
 *
 * Keep the upstream header and its GPL-2.0-or-later notice intact.
 */
#ifndef INFINITY_HUSK_RUNTIME_BRIDGE_H
#define INFINITY_HUSK_RUNTIME_BRIDGE_H

#include "../../Vendor/Husk/translation-layer-next/husk-tl-unity-app.h"

#endif /* INFINITY_HUSK_RUNTIME_BRIDGE_H */
