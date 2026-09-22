# mempy

mempy is the compiler manipulation language which would also be the communicator between the compiler and many other programming languages like C, C++, Python, rust, and other industry standard programming languages, this is a pure-out-of-assembly language, all the logic of the language is from the compiler itself, and the compiler is completely pure of of other compilers,

currently the compiler is for x86_64 processors, but once the using the same logic to create one for arm isn't that hard, As i said, this is revolutionary, imagine playing gta 6 on a 2010 intel platinum. this takes efficiency of each cpu cycle to the max,

this is not stolen content, this is original, before we go to the compiler, i want to give you the structure of it,

1. mempy ;this is the folder that encloses all the logic, there will be a version of this for each OS like mempy-Windows, mwmpy-mac

2. mempy/ ;system_hooks, language_hooks, compiler ;;language_hooks: depending on the OS, the files that contain CPU, GPU info are scattered, this is the problem ;; language_hooks, this is where the language translators stay the code that translates javascript to mempy, etc, etc,... (that is the idea but might as well create a website where these hooks can be found and installed for individual languages.) ;; compiler: holds the compiler.asm as well as a hardware file that contains infromation from the system_hooks that are os_id(which os you are using), number of cpu cores, number of gpu cores, vector scale(SIMD scale), os_write_id(for creating files), os_qxit_id(for exiting the compiler), 

3. mempy/system_hooks/ cpu, gpu, system ;; cpu: straight up asks the hardware how many cores its got(even if you got a 1 core cpu(custom) or a core loose cpu) via the cpuid, also asks for the vector value while at it. ;;gpu: fetches the number of blocks GPU has got. ;; fetches the systems write, exit and id ;; these all are sent directly to the hardware folder in mempy/compiler/hardware at boot

4. mempy/compiler/ hardware, compiler ;; hardware: holds those elements like: O=1(linux), N=1, G=1, V=1, w=1, E=60(linux)

let's speak of mempy, it is a semicolon seperative language, where commenting is exclusive to within/* */ format, and assignments like python, x = 5; there are only "()", no "{}" nor "[]" the special characters allowed in this language are >, <, !, =, <=, >=, *, -, +, / and letters from a-z, A-Z and numbers from 0-9, this language is case sensitive only small case for keywords, only keyword is if. nested structures are allowed, ((())), the errors are based on semicolons not lines, so use newline to keep track of which sentence the compiler is reffering to. anything within quotes is neglected, anycharacter that is not within quotes and not in the set of alloted are seen as ghosts and cleared at the very first stage, the comiler clears all spaces, newlines, and undefined characters at the first pass. 

the compiler archetecture has 3 passes, 1 for cleaning the code and leaving no headerspace, 2nd is for checking the memory safety and 3rd for the stiching after the script was processed. the cpu works at a race-to-work condition rather than a sequence.
considered 30x faster than llvm.
