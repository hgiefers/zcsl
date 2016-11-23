/*
 * Copyright International Business Machines Corporation 2016
 *
 * Printed in the United States of America June 2016
 *
 * IBM, the IBM logo, and ibm.com are trademarks or registered trademarks of
 * International Business Machines Corp.,
 * registered in many jurisdictions worldwide. Other product and service names
 * might be trademarks of IBM or other companies. A current list of IBM trademarks
 * is available on the Web at “Copyright and trademark information” at
 * www.ibm.com/legal/copytrade.shtml.
 *
 * Other company, product, and service names may be trademarks or service marks of
 * others.
 *
 * All information contained in this document is subject to change without notice.
 * The products described in this document are NOT intended for use in applications
 * such as implantation, life support, or other hazardous uses where malfunction
 * could result in death, bodily injury, or catastrophic property damage. The
 * information contained in this document does not affect or change IBM product
 * specifications or warranties. Nothing in this document shall operate as an
 * express or implied license or indemnity under the intellectual property rights
 * of IBM or third parties. All information contained in this document was obtained
 * in specific environments, and is presented as an illustration. The results
 * obtained in other operating environments may vary.
 * While the information contained herein is believed to be accurate, such
 * information is preliminary, and should not be relied upon for accuracy or
 * completeness, and no representations or warranties of accuracy or completeness
 * are made.
 *
 * Note: This document contains information on products in the design, sampling
 * and/or initial production phases of development. This information is subject to
 * change without notice. Verify with your IBM field applications engineer that you
 * have the latest version of this document before finalizing a design.
 * This document is intended for development of technology products compatible with
 * Power Architecture. You may use this document, for any purpose (commercial or
 * personal) and make modifications and distribute; however, modifications to this
 * document may violate Power Architecture and should be carefully considered. Any
 * distribution of this document or its derivative works shall include this Notice
 * page including but not limited to the IBM warranty disclaimer and IBM liability
 * limitation. No other licenses, expressed or implied, estoppel or otherwise to
 * any intellectual property rights is granted by this document.
 *
 * THE INFORMATION CONTAINED IN THIS DOCUMENT IS PROVIDED ON AN “AS IS” BASIS.
 * IBM makes no representations or warranties, either express or implied, including
 * but not limited to, warranties of merchantability, fitness for a particular
 * purpose, or non-infringement, or that any practice or implementation of the IBM
 * documentation will not infringe any third party patents, copyrights, trade
 * secrets, or other rights. In no event will IBM be liable for damages arising
 * directly or indirectly from any use of the information contained in this
 * document.
 *
 * IBM Systems and Technology Group
 * 2070 Route 52, Bldg. 330
 * Hopewell Junction, NY 12533-6351
 * The IBM home page can be found at ibm.com.
 */

// IBM Research - Zurich
// Zurich CAPI Streaming Layer
// Raphael Polig <pol@zurich.ibm.com>
// Heiner Giefers <hgi@zurich.ibm.com>

#include <sys/time.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <poll.h>
#include <endian.h>
#include <getopt.h>
#include <fcntl.h>
#include <errno.h>
#include <math.h>  

#include "libcxl.h"

#define DEVICE "/dev/cxl/afu0.0d"

#define FFT_SAMPLES 4096
#define CACHELINESIZE   128

void init_data(__u8 *datap, uint32_t chunkSize, uint32_t ffts, float amp, float freq);

struct wed {
  uint32_t volatile flags;	//
  uint32_t size;		//
  uint8_t* from;
  uint8_t* to;
  uint64_t reserved03;
  uint64_t reserved04;
  uint64_t reserved05;
  uint64_t reserved06;
  uint64_t reserved07;
  uint64_t reserved08;
  uint64_t reserved09;
  uint64_t reserved10;
  uint64_t reserved11;
  uint64_t reserved12;
  uint64_t reserved13;
  uint64_t reserved14;
  uint64_t reserved15;
};


int main (int argc, char *argv[]) {
	printf("Zurich CAPI Streaming Layer (ZCSL) FFT TEST ...\n");

	uint32_t chunkSize = 8*FFT_SAMPLES; // Size of a single transfer
	
	int i, j, ffts = 1;
	if(argc>1)
		ffts = atoi(argv[1]);

	int n = 1;
	if(argc>2)
		n = atoi(argv[2]);

	uint32_t copyData = ffts * chunkSize; // Adjust for any roundings	

	struct cxl_event *event = (struct cxl_event *) malloc(sizeof(struct cxl_event));
	struct cxl_event_afu_interrupt irq;

	struct cxl_afu_h *afu_h;
  afu_h = cxl_afu_open_dev(DEVICE);
	if (!afu_h) {
		perror("cxl_afu_open_dev");
		return -1;
	}

	// Prepare WEDs
	struct wed **weds = (struct wed **) malloc(n*sizeof(struct wed*));

	for(i=0;i<n;i++){
		if(posix_memalign ((void **) &weds[i], CACHELINESIZE, sizeof (struct wed))) {
			perror("posix_memalign");
			return(-1);
		}
		printf("Allocated WED memory @ 0x%016"PRIx64"\n", (uint64_t) weds[i]);
		weds[i]->flags = (i<n-1) ? 1 : 0;
		weds[i]->size  = copyData;
	
		if(posix_memalign ((void **) &weds[i]->from, CACHELINESIZE, weds[i]->size)) {
			perror("posix_memalign");
			return(-1);
		}
		printf("Allocated WED->FROM memory @ 0x%016"PRIx64"\n", (uint64_t) weds[i]->from);
	
		if(posix_memalign ((void **) &weds[i]->to, CACHELINESIZE, weds[i]->size)) {
			perror("posix_memalign");
			return(-1);
		}
		printf("Allocated weds[%d]->to memory @ 0x%016"PRIx64"\n", i, (uint64_t) weds[i]->to);
	
		memset(weds[i]->to, 0, ffts*chunkSize);
		init_data(weds[i]->from, chunkSize, ffts, 1.4324, 6);

		printf("WED  (From/To)  (0x%016"PRIx64"/0x%016"PRIx64")\n", (uint64_t) weds[i]->from, (uint64_t) weds[i]->to);

	}

	 // Start AFU
  cxl_afu_attach (afu_h, (uint64_t) weds[0]);

  // Map AFU MMIO registers, if needed
  printf ("Mapping AFU registers...\n");
  if((cxl_mmio_map(afu_h, CXL_MMIO_BIG_ENDIAN)) < 0) {
    perror("cxl_mmio_map:"DEVICE);
    return(-1);
  }

	#ifdef RUNSIM
		for(i=0;i<n;i++){
			printf("Send Job to Simulator\n"); fflush(stdout);
			cxl_mmio_write64(afu_h, 0x80, (uint64_t)weds[i]);
		}
	#else
    for(i=0;i<n;i++){
			printf("Send Job to FPGA\n"); fflush(stdout);
			cxl_mmio_write64(afu_h, 0x80, __bswap_64((uint64_t)weds[i]));
    }
	#endif
	
	cxl_read_event(afu_h, event);
	irq = event->irq;
	printf("Catched IRQ %u %u \n", irq.flags, irq.irq);


  // Unmap AFU MMIO registers, if previously mapped
  cxl_mmio_unmap(afu_h);

  // Free AFU
  cxl_afu_free(afu_h);

	/********************************************************************************
	*********************************************************************************
	****************** V I S U A L I Z E   R E S U L T S ****************************
	*********************************************************************************
	********************************************************************************/

	FILE *fp = NULL;
	fp = fopen ("source.dat", "w");
	for (i=0; i<n; i++){
		for (j=0; j<2*FFT_SAMPLES; j+=2){
			fprintf(fp, "%d %e %e\n", j/2, ((float*) weds[i]->from)[j], ((float*) weds[i]->from)[j+1]);
		}
	}
	fclose(fp);

	fp = fopen ("transformed.dat", "w");
	float mfreq = 0.0;
	int mfreqi = 0;
	for (i=0; i<n; i++){
		for (j=0; j<2*FFT_SAMPLES; j+=2){
			fprintf(fp, "%d %e %e\n", j/2, ((float*) weds[i]->to)[j], ((float*) weds[i]->to)[j+1]);
			if( ((float*) weds[i]->to)[j] > mfreq ){
				mfreq =  ((float*) weds[i]->to)[j];
				mfreqi = j/2;
			}
		}
	}
	fclose(fp);

	system("gnuplot -e \"set terminal dumb 200 40; set autoscale; plot 'source.dat' u 1:2 w lines\"");
	printf("\n\t\tFrequency = %d\n", mfreqi);
	printf("\n\t\tAmplitude = %f\n\n\n", 2*mfreq/FFT_SAMPLES);

	return(0);	
}









void init_data(__u8 *datap, uint32_t chunkSize, uint32_t ffts, float amp, float freq)
{
        int i, r;

        typedef union
        {
                  float f;
                  uint32_t u;
        } float_uint_u;

        uint32_t *cmplx = (uint32_t*) malloc(chunkSize);

        float_uint_u fc_re, fc_im;
        int num_points = chunkSize/(2*sizeof(float));
        for (i=0; i<num_points; i++){
        	fc_re.f = amp*cos(i*freq*(2*3.1415926535)/num_points);
					fc_im.f = 0.0;
        	#ifdef SWAPDATA
        		fc_re.u = __bswap_32(fc_re.u);
        		fc_im.u = __bswap_32(fc_im.u);
        	#endif
        	cmplx[2*i] = fc_re.u;
        	cmplx[2*i+1] = fc_im.u;
        }
        for (r=0; r<ffts; r++){
        	memcpy(datap+(r*chunkSize), cmplx, chunkSize);	
        }
        free (cmplx);
}
