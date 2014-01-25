/*
 * file        : hash_api.h
 * version     : 1.0.208
 * date        : 14.12.2010
 * 
 * Fugue vperm implementation Hash API
 *
 * Cagdas Calik
 * ccalik@metu.edu.tr
 * Institute of Applied Mathematics, Middle East Technical University, Turkey.
 *
 */
#ifdef __cplusplus
extern "C"
{
#endif

#ifndef HASH_API_H
#define HASH_API_H


#ifdef AES_NI
#define HASH_IMPL_STR	"Fugue-aesni"
#else
#define HASH_IMPL_STR	"Fugue-vperm"
#endif

#include "sha3_common.h"

#ifdef AES_NI
#include <wmmintrin.h>
#else
#include <tmmintrin.h>
#endif


typedef struct
{
	__m128i			state[12];
	unsigned int	base;

	unsigned int	uHashSize;
	unsigned int	uBlockLength;
	unsigned int	uBufferBytes;
	DataLength		processed_bits;
	uint64_t		buffer[4];

} hashState;




void Init(hashState *ctx, int nHashSize);

void Update(hashState *state, uint64_t *data, DataLength databitlen);

void Final(hashState *state, uint64_t *hashval);

HashReturn Hash(int hashbitlen, const BitSequence *data, DataLength databitlen, BitSequence *hashval);



#endif // HASH_API_H

#ifdef __cplusplus
}
#endif

