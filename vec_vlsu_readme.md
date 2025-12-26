# Vector Load Store Unit

## Description

- A Vector Coprocessor Load/Store Unit (VLSU) is responsible for efficiently handling memory access operations, such as loading data from memory into vector registers and storing data from vector registers back to memory. 
## Features of VLSU

- Vector loads and stores move values between vector registers and memory, enabling data transfer between the vector register file and external memory locations.
  
- **Masked Operations:** Vector loads and stores are masked, meaning they do not update inactive elements in the destination vector register. Masking ensures that operations only affect the active elements, which can be configured using a **vector mask** (`vm`), providing flexible control over which elements to load/store.

- **Memory Addressing**: Supports various addressing modes including unit-stride, stride-based, and indexed addressing. 

- **Scalar Registers for Addressing**: Scalar registers (`rs1` for base address, `rs2/3/4` for stride or address offsets) are used in conjunction with the vector registers to define memory access patterns.
  
- **Memory Operand Encodings**: The LSU supports multiple memory addressing modes, enabling both contiguous and strided memory accesses. These modes can be combined with different vector widths and lengths to optimize memory bandwidth and performance.

## Important Terminologies for Vector Load and Store Unit (VLSU) Registers

- ### `rs1[4:0]`
    - Specifies the **X register** holding the **base address** for vector memory operations. This register is used as the starting point for memory access during load/store instructions.

- ### `rs2[4:0]`
    - Specifies the **X register** holding the **stride value**. This value determines the step size or distance between consecutive memory addresses when using **strided** memory access in vector operations.

- ### `vs2[4:0]`
    - Specifies the **V register** that holds the **address offsets** in indexed operations. These offsets define non-contiguous memory addresses for gathering or scattering vector elements.

- ### `vd[4:0]`
    - Specifies the **V register** destination for **load operations**. It indicates where in the vector register file the loaded data from memory will be written.

- ### `vm`
    - Controls **vector masking** for load/store operations. When `vm=0`, masking is enabled, meaning inactive vector elements are not updated. When `vm=1`, masking is disabled, and all elements are updated regardless of the mask.

- ### `width[2:0]`
    - Defines the **size of memory elements** and differentiates from floating-point scalar operations. 
- ### `mew`
    - Stands for **extended memory element width** and is used in conjunction with width to support larger element sizes during memory operations.

- ### `mop[1:0]`
    - Specifies the **memory addressing mode**:
        - `00`: Unit-stride (contiguous memory access).
        - `01`: Indexed-unordered (scattered accesses with no specific order).
        - `10`: Strided (memory access with fixed strides).
        - `11`: Indexed-ordered (gathered/scattered accesses with order).


## Pinout Diagram 
The pinout diagram of the vector load store unit is given below:

![VLSU_Pinout](/docs/vector_processor_docs/vlsu_pinout_diagram.png)

## Block Diagrams of the Vector Load/Store Unit (VLSU)

The **Vector Load/Store Unit (VLSU)** operates in various modes to handle memory transactions. Below, we describe the block diagrams for different VLSU addressing modes, including **Unit Stride**, **Stride**, and **Gather** operations.

### General Address Calculation:
- **Unit Stride**: 
  - The **next address** is calculated as `previous address + 1`.
  - The number of cycles required to complete the operation equals the number of elements, determined by the formula:
    \[
    \text{No. of Elements} = \frac{VLEN \times LMUL}{SEW}
    \]
    where:
    - `VLEN`: Vector Length
    - `LMUL`: Length Multiplier
    - `SEW`: Standard Element Width (bits per vector element)

- **Stride**: 
  - The **next address** is calculated as `previous address + stride (rs2)`. Here, `rs2` holds the stride value.

- **Gather**: 
  - The **next address** is calculated as `previous address + vs[i]`, where `vs[i]` holds the vector of address offsets for each element.

### Modes

#### 1. **Unit Stride**
- **Description**: 
    - In **Unit Stride**, memory addresses for vector elements are accessed in contiguous order (i.e., the next element address is incremented by 1 from the previous address).

#### 2. **Stride**
- **Description**: 
  - In **Stride Mode**, memory addresses for vector elements are spaced at regular intervals determined by a **stride value** (held in the `rs2` register). This allows non-contiguous memory accesses with a fixed pattern.
  
#### 3. **Gather**
- **Description**: 
  - In **Gather Mode**, each memory element has a unique address offset, defined by the values in the `vs` vector register. This is used for gathering elements from scattered memory locations.


### Block Diagrams Overview

This section provides block diagrams for both the **Datapath** and the **Controller** of the system.
#### 1. **Datapath Block Diagram**

- **Description**:  
  The **Datapath** handles the memory access in **Unit Stride** and **Stride** modes, which can be seen below.
  
- **Block Diagram**:

  ![VLSU Datapath Block Diagram](/docs/vlsu_docs/vlsu_datapath.png)

#### 2. **Controller Block Diagram**

- **Description**:  
  The **Controller** is responsible for coordinating the memory access modes, including both **Unit Stride** and **Stride Mode**. It ensures that the memory access patterns, either contiguous or non-contiguous, are executed correctly based on the stride value stored in the `rs2` register.

- **Block Diagram**:

  ![Controller Block Diagram](/docs/vlsu_docs/vlsu_controller.png)

# Getting Started

## Installation of Vivado  

## Build Model and Run Simulation

### Simulation with Verilator
