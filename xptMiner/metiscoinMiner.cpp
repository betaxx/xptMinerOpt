#include"global.h"

#define GROUPED_HASHES  (32)

void metiscoin_process(minerMetiscoinBlock_t* block)
{
    sph_keccak512_context ctx_keccak_init;
    //sph_keccak512_init(&ctx_keccak_init);
    //sph_keccak512(&ctx_keccak_init, &block->version, 80 - 4);
    
    // shavite512
    sph_shavite512_context ctx_shavite_init;
    sph_shavite512_init(&ctx_shavite_init);
    
    // metis512
    sph_metis512_context ctx_metis_init;
    sph_metis512_init(&ctx_metis_init);
    
    
    // "Working" sets
    sph_keccak512_context   ctx_keccak;
    sph_shavite512_context  ctx_shavite;
    sph_metis512_context    ctx_metis;
    

	static unsigned char pblank[1];
	block->nonce = 0;

	uint32 target = *(uint32*)(block->targetShare+28);
	uint64 hash0[8*GROUPED_HASHES];
	uint64 hash2[8];
	// since only the nonce changes we can calculate the first keccak round in advance
	unsigned long long keccakPre[25];
	sph_keccak512_init(&ctx_keccak);
	keccak_core_prepare(&ctx_keccak, block, keccakPre);
	for(uint32 n=0; n<0x1000; n++)
	{
		if( block->height != monitorCurrentBlockHeight )
			break;
		for(uint32 f=0; f<0x8000; f += GROUPED_HASHES)
		{

		// todo: Generate multiple hashes for multiple nonces at once
		block->nonce = n*0x10000+f;
		for(uint32 i=0; i<GROUPED_HASHES; i++)
		{
		  keccak_core_opt(&ctx_keccak, keccakPre, *(unsigned long long*)(&block->nBits), hash0+i*8);
		  block->nonce++;
		}
		for(uint32 i=0; i<GROUPED_HASHES; i++)
		{
		  memcpy(&ctx_shavite, &ctx_shavite_init, sizeof(sph_shavite512_context));
		  sph_shavite512(&ctx_shavite, hash0+i*8, 64);
		  sph_shavite512_close(&ctx_shavite, hash0+i*8);
		}
		block->nonce = n*0x10000+f;
		for(uint32 i=0; i<GROUPED_HASHES; i++)
		{
		  memcpy(&ctx_metis,   &ctx_metis_init,   sizeof(sph_metis512_context)  );
		  sph_metis512(&ctx_metis, hash0+i*8, 64);
		  sph_metis512_close(&ctx_metis, hash2);
		  if( *(uint32*)((uint8*)hash2+28) <= target )
		  {
			totalShareCount++;
			//block->nonce = rawBlock.nonce;
			xptMiner_submitShare(block);
		  }
		  block->nonce++;
		}
		}
		totalCollisionCount += 1; // count in steps of 0x8000
	}
}
