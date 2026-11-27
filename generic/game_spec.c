/*
 * game_spec.c — GameSpec genérico do Mega Drive (genesisrecomp-web). Entrada, V-int e H-int saem da
 * tabela de vetores do próprio cartucho, lida na hora; o interpretador ("Tier-3 floor") fica ligado
 * pra cobrir o que a descoberta estática não achou, e registra isso pra próxima rodada de perfil.
 */
#include "game_spec.h"
#include "genesis_runtime.h"
#include <stddef.h>
#include <stdint.h>

static uint32_t rom_long(uint32_t a)
{
    return ((uint32_t)g_rom[a] << 24) | ((uint32_t)g_rom[a + 1] << 16) | ((uint32_t)g_rom[a + 2] << 8) | g_rom[a + 3];
}
static void generic_call_entry_point(void) { recomp_call_addr(rom_long(0x04) & 0xFFFFFFu); }
static void generic_call_vblank(void)      { recomp_call_addr(rom_long(0x78) & 0xFFFFFFu); }
static void generic_call_hblank(void)      { recomp_call_addr(rom_long(0x70) & 0xFFFFFFu); }

const GameSpec g_game_spec = {
    .video                  = NULL,
    .display_name           = "Mega Drive",
    .short_name             = "MD",
    .expected_rom_crc32     = 0u,
    .expected_rom_size      = 0u,
    .tier3_floor_default    = 1,
    .call_entry_point       = generic_call_entry_point,
    .call_vblank            = generic_call_vblank,
    .call_hblank            = generic_call_hblank,
};
