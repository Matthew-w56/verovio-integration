#include <stdio.h>
#include <windows.h> // notice this! you need it! (windows)

int main(){
	int delay = 200;
	printf("Welcome! I am going to show you a %dms delay!\n", delay);
	printf("Just press enter when you're ready.  And enter 'q' when you're done.");
	while (1) {
		delay = 200;
		char* userIn;
		printf("\n%d> ", delay);
		scanf("%s", &userIn);
		printf("Start.. ");
		Sleep(delay);
		printf("Finish!");
	}
	printf("Goodbye!");
    return 0;
}