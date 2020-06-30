#include <stdio.h>

int main(void) {
	int s[64];
	int key[32] = {120, 70, 76, 51, 77, 50, 83, 90, 81, 57, 74, 53, 117, 72, 51, 98, 54, 110, 76, 120, 49, 99, 77, 48, 68, 65, 54, 67, 52, 90, 67, 77};

	for(int i=0; i<64; i++) {
		s[i] = i;
	}

	int j = 0;
	for(int i=0; i<64; i++) {
		j = (j + s[i] + key[i % 32])% 64;
		int tmp = s[j];
		s[j] = s[i];
		s[i] = tmp;
	}
	
	int l = 0;
	int k = 0;

	int out;
	while(1) {
		int in;
		scanf("%x", &in);
		l = (l+1) % 64;
		k = (k + s[l]) % 64;
	 	int tmp = s[k];
		s[k] = s[l];
		s[l] = tmp;
		out = in ^ s[(s[l]+s[k]) % 64];
		printf("%x\n", out);
	}
	
	return 0;
}
