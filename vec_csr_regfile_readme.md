# Vector CSR file

## Description

- Vector CSR File contains only seven csr registers (e.g., vstart, vcsr, vsat, vxrm, vtype, vlen, vlenb). These registers are used for the configuration of vectors. Each csr register can store 32 data.

## Seven CSR Registers
- vtype (implemented)
- vlen (implemented)
- vstart
- vsat
- vxrm
- vlenb

## Vtype Register
- This register has different bit fields for the vector configuration. First three bits hold the value of vlmul which is use for the grouping of the registers. The next three bits hold the configuration of sew (standarad element width) in a vector register i.e. this bit field decide the single element width in a single vector register.

## Vlen Register 
- This register holds the length of the vector which is used during execution.

## Vector CSR Datapath
 ![Diagram](/docs/decode-docs/vec-csr-regfile.png)
