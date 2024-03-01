from time import sleep
import sys

# Delay in ms
delay = 100

print("Get ready to see the delay!  I'll show you a " + str(delay) + "ms delay when you press enter.")
print("When you're done, enter 'quit'")

delay_in_seconds = delay / 1000
print(delay_in_seconds)

while True:
    print("Okay I'm ready:")
    userIn = input()
    if userIn == "quit":
        break
    print("start", end=" ")
    sys.stdout.flush()
    sleep(delay_in_seconds)
    print("stop")
    sys.stdout.flush()

print("\nGoodbye!")


