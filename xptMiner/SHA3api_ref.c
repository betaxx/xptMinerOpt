
#include "SHA3api_ref.h"
#include "fugue.h"

// fugue_vperm.asm includes
void compress256(unsigned int *pmsg, unsigned long long uBlocks);
void compress384(unsigned int *pmsg, unsigned long long uBlocks);
void compress512(unsigned int *pmsg, unsigned long long uBlocks);

void loadstate256(unsigned int *pustate);
void loadstate512(unsigned int *pustate);

void storestate256(unsigned int *pustate);
void storestate512(unsigned int *pustate);

void (*compress)(unsigned int *pmsg, unsigned long long uBlocks);
void (*loadstate)(unsigned int *pustate);
void (*storestate)(unsigned int *pustate);



HashReturn
Init (hashState *state, int hashbitlen)
{
    if (Init_Fugue(state, hashbitlen)) 
	{
		if(hashbitlen == 224 || hashbitlen == 256)
		{
			asm("call loadstate256": :"c"(state->State));

			//compress = compress256;
			//loadstate = loadstate256;
			//storestate = storestate256;
		}
		else
		{
			asm("call loadstate512": :"c"(state->State));

			//if(hashbitlen == 384)
			//	compress = compress384;
			//else
			//	compress = compress512;

			//loadstate = loadstate512;
			//storestate = storestate512;
		}

		//loadstate(state->State);

		return SUCCESS;
	}

    return FAIL;
}

HashReturn
Update (hashState *state, const BitSequence *data, DataLength databitlen)
{
	unsigned long long uBlocks;

    if (!state || !state->Cfg)
        return FAIL;
    if (!databitlen)
        return SUCCESS;
    if (state->TotalBits&7)
        return FAIL;
    if (state->TotalBits&31)
    {
        int need = 32-(state->TotalBits&31);
        if (need>databitlen)
        {
            memcpy ((uint8*)state->Partial+((state->TotalBits&31)/8), data, (databitlen+7)/8);
            state->TotalBits += databitlen;
            return SUCCESS;
        }
        else
        {
            memcpy ((uint8*)state->Partial+((state->TotalBits&31)/8), data, need/8);

	  	//Next_Fugue (state, state->Partial, 1);            
		//compress(state->Partial, 1);
	uBlocks = 1;
	if(state->hashbitlen == 224 || state->hashbitlen == 256)
	{
		asm("call compress256": \
					  :"c"(state->Partial), "d"(uBlocks)\
					  : "%rax");
	}
	else if(state->hashbitlen == 384)
	{
		asm("call compress384": \
					  :"c"(state->Partial), "d"(uBlocks)\
					  : "%rax");
	}
	else
	{
		asm("call compress512": \
					  :"c"(state->Partial), "d"(uBlocks)\
					  : "%rax");
	}

		state->TotalBits += need;
            databitlen -= need;
            data += need/8;
        }
    }
    if (databitlen>31)
    {
        //Next_Fugue (state, (uint32*)data, databitlen/32);
	//compress(data, databitlen/32);
	if(state->hashbitlen == 224 || state->hashbitlen == 256)
	{
		asm("call compress256": \
					  :"c"(data), "d"(databitlen/32)\
					  : "%rax");

	}
	else if(state->hashbitlen == 384)
	{
		asm("call compress384": \
					  :"c"(data), "d"(databitlen/32)\
					  : "%rax");

	}
	else
	{
		asm("call compress512": \
					  :"c"(data), "d"(databitlen/32)\
					  : "%rax");
	}

		// Warning: For debuggin purposes only. Calling storestate() here corrupts state registers.
		//storestate(state->State);

	state->TotalBits += (databitlen/32)*32;
        data += (databitlen/32)*4;
        databitlen &= 31;
    }
    if (databitlen)
    {
        memcpy ((uint8*)state->Partial, data, (databitlen+7)/8);
        state->TotalBits += databitlen;
    }
    return SUCCESS;
}

HashReturn
Final (hashState *state, BitSequence *hashval)
{
	unsigned long long uBlocks;

    if (!state || !state->Cfg)
        return FAIL;
    if (state->TotalBits&31)
    {
        int need = 32-(state->TotalBits&31);
        memset ((uint8*)state->Partial+((state->TotalBits&31)/8), 0, need/8);

		//Next_Fugue (state, state->Partial, 1);
		//compress(state->Partial, 1);
	uBlocks = 1;

	if(state->hashbitlen == 224 || state->hashbitlen == 256)
	{
		asm("call compress256": \
					  :"c"(state->Partial), "d"(uBlocks)\
					  : "%rax");
	}
	else if(state->hashbitlen == 384)
	{
		asm("call compress384": \
					  :"c"(state->Partial), "d"(uBlocks)\
					  : "%rax");
	}
	else
	{
		asm("call compress512": \
					  :"c"(state->Partial), "d"(uBlocks)\
					  : "%rax");
	}


    }

	//

	if(state->hashbitlen == 224 || state->hashbitlen == 256)
	{
		state->Base = ((state->TotalBits + 31) / 32);
		state->Base += 2;
		state->Base %= 5;
		state->Base = (30 - 6 * state->Base) % 30;
	}
	else if(state->hashbitlen == 384)
	{
		state->Base = ((state->TotalBits + 31) / 32);
		state->Base += 2;
		state->Base %= 4;
		state->Base = (36 - 9 * state->Base) % 36;
	}
	else
	{
		state->Base = ((state->TotalBits + 31) / 32);
		state->Base += 2;
		state->Base %= 3;
		state->Base = (36 - 12 * state->Base) % 36;
	}

	state->TotalBits = HO2BE_8 (state->TotalBits);


	
	//Next_Fugue (state, (uint32*)&state->TotalBits, 2);
	//compress((uint32*)&state->TotalBits, 2);
	uBlocks = 2;


	if(state->hashbitlen == 224 || state->hashbitlen == 256)
	{
	asm("call compress256": \
			      :"c"((uint32*)&state->TotalBits), "d"(uBlocks)\
			      : "%rax");
	}
	else if(state->hashbitlen == 384)
	{
	asm("call compress384": \
			      :"c"((uint32*)&state->TotalBits), "d"(uBlocks)\
			      : "%rax");
	}
	else
	{
	asm("call compress512": \
			      :"c"((uint32*)&state->TotalBits), "d"(uBlocks)\
			      : "%rax");
	}


	//storestate(state->State);
	if(state->hashbitlen == 224 || state->hashbitlen == 256)
		asm("call storestate256": :"c"(state->State));
	else
		asm("call storestate512": :"c"(state->State));

	Done_Fugue (state, (uint32*)hashval, NULL);

    return SUCCESS;
}

HashReturn
Hash (int hashbitlen, const BitSequence *data, DataLength databitlen, BitSequence *hashval)
{
    hashState HS;

    if (Init (&HS, hashbitlen) == SUCCESS)
        if (Update (&HS, data, databitlen) == SUCCESS)
            return Final (&HS, hashval);
    return FAIL;
}

