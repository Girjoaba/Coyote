# Simulation container

A container that runs the Coyote simulation of one example under Verilator.

On the machine with Vivado (example 1):

```bash
cd build_hw && cmake -DFDEV_NAME=u55c -DUNIT_TEST_DIR=<coyote>/sim/unit_test/examples <coyote>/examples/01_hello_world/hw && make sim
<coyote>/sim/vl/build.sh build_hw build_vl
<coyote>/sim/vl/freeze.sh build_hw build_vl frozen
```

We freeze Coyote shell RTL and Xilinx IP, such that you can simulate your applications easily by only verilating it. Freezing allows you to run the applications on machines without Vivado.

Then one of:

```bash
apptainer build --fakeroot --build-arg COYOTE=<coyote> --build-arg FROZEN=frozen coyote-sim.sif <coyote>/sim/container/coyote-sim.def
apptainer run --writable-tmpfs coyote-sim.sif -X 1024 -r 1 -s 0

docker build -f sim/container/Dockerfile --build-arg FROZEN=sim/container/frozen -t coyote-sim <coyote>
docker run --rm coyote-sim -X 1024 -r 1 -s 0
```

Both call `install.sh` and then `run.sh`, followed by the Python tests of `sim/unit_test/examples` under Verilator, with the first failure as the exit code.

The build takes about 10 minutes and the run about 30 seconds, because the Python flow builds its own testbench binary on the first run.
