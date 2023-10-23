---
v: 3

title: A Concise Binary Object Representation (CBOR)-based Serialization Format for the Software Updates for Internet of Things (SUIT) Manifest
abbrev: CBOR-based SUIT Manifest
docname: draft-ietf-suit-manifest-23
ipr: trust200902
category: std
stream: IETF

area: Security
workgroup: SUIT
keyword: Internet-Draft

pi:
  rfcedstyle: yes
  toc: yes
  tocindent: yes
  sortrefs: yes
  symrefs: yes
  strict: yes
  comments: yes
  inline: yes
  text-list-symbols: -o*+
  docmapping: yes
  toc_levels: 4

author:
 -
      ins: B. Moran
      name: Brendan Moran
      organization: Arm Limited
      email: brendan.moran.ietf@gmail.com

 -
      ins: H. Tschofenig
      name: Hannes Tschofenig
      email: hannes.tschofenig@gmx.net

 -
      ins: H. Birkholz
      name: Henk Birkholz
      organization: Fraunhofer SIT
      email: henk.birkholz@sit.fraunhofer.de

 -
      ins: K. Zandberg
      name: Koen Zandberg
      organization: Inria
      email: koen.zandberg@inria.fr

 -
      ins: Ø. Rønningstad
      name: Øyvind Rønningstad
      organization: Nordic Semiconductor
      email: oyvind.ronningstad@gmail.com

normative:
  RFC4122:
  RFC9052: cose
#  RFC9053: cose-algs
  RFC3986:
  RFC8949:
  RFC9019:
  RFC9124:
  I-D.ietf-suit-mti:
  RFC9090: oid
  RFC9054: hash-algs


informative:
  I-D.ietf-teep-architecture:
  I-D.ietf-suit-firmware-encryption:
  I-D.ietf-suit-update-management:
  I-D.ietf-suit-trust-domains:
  I-D.ietf-suit-report:
  RFC7228:
  YAML:
    title: "YAML Ain't Markup Language"
    author:
    date: 2020
    target: https://yaml.org/
  COSE_Alg:
    title: "COSE Algorithms"
    author: IANA
    date: 2023
    target: https://www.iana.org/assignments/cose/cose.xhtml#algorithms

--- abstract
This specification describes the format of a manifest.  A manifest is
a bundle of metadata about code/data obtained by a recipient (chiefly
the firmware for an IoT device), where to find the code/data, the
devices to which it applies, and cryptographic information protecting
the manifest. Software updates and Trusted Invocation both tend to use
sequences of common operations, so the manifest encodes those sequences
of operations, rather than declaring the metadata.

--- middle

#  Introduction

A firmware update mechanism is an essential security feature for IoT devices to deal with vulnerabilities. The transport of firmware images to the devices themselves is important security aspect. Luckily, there are already various device management solutions available offering the distribution of firmware images to IoT devices. Equally important is the inclusion of metadata about the conveyed firmware image (in the form of a manifest) and the use of a security wrapper to provide end-to-end security protection to detect modifications and (optionally) to make reverse engineering more difficult. Firmware signing allows the author, who builds the firmware image, to be sure that no other party (including potential adversaries) can install firmware updates on IoT devices without adequate privileges. For confidentiality protected firmware images it is additionally required to encrypt the firmware image and to distribute the content encryption key securely. The support for firmware and payload encryption via the SUIT manifest format is described in a companion document {{I-D.ietf-suit-firmware-encryption}}. Starting security protection at the author is a risk mitigation technique so firmware images and manifests can be stored on untrusted repositories; it also reduces the scope of a compromise of any repository or intermediate system to be no worse than a denial of service.

A manifest is a bundle of metadata about the firmware for an IoT device, where to
find the firmware, and the devices to which it applies.

This specification defines the SUIT manifest format and it is intended to meet several goals:

* Meet the requirements defined in {{RFC9124}}.
* Simple to parse on a constrained node.
* Simple to process on a constrained node.
* Compact encoding.
* Comprehensible by an intermediate system.
* Expressive enough to enable advanced use cases on advanced nodes.
* Extensible.

The SUIT manifest can be used for a variety of purposes throughout its lifecycle, such as:

* a Network Operator to reason about compatibility of a firmware, such as timing and acceptance of firmware updates.
* a Device Operator to reason about the impact of a firmware.
* a device to reason about the authority & authenticity of a firmware prior to installation.
* a device to reason about the applicability of a firmware.
* a device to reason about the installation of a firmware.
* a device to reason about the authenticity & encoding of a firmware at boot.

Each of these uses happens at a different stage of the manifest lifecycle, so each has different requirements.

It is assumed that the reader is familiar with the high-level firmware update architecture {{RFC9019}} and the threats, requirements, and user stories in {{RFC9124}}.

The design of this specification is based on an observation that the vast majority of operations that a device can perform during an update or Trusted Invocation are composed of a small group of operations:

* Copy some data from one place to another
* Transform some data
* Digest some data and compare to an expected value
* Compare some system parameters to an expected value
* Run some code

In this document, these operations are called commands. Commands are classed as either conditions or directives. Conditions have no side-effects, while directives do have side-effects. Conceptually, a sequence of commands is like a script but the language is tailored to software updates and Trusted Invocation.

The available commands support simple steps, such as copying a firmware image from one place to another, checking that a firmware image is correct, verifying that the specified firmware is the correct firmware for the device, or unpacking a firmware. By using these steps in different orders and changing the parameters they use, a broad range of use cases can be supported. The SUIT manifest uses this observation to optimize metadata for consumption by constrained devices.

While the SUIT manifest is informed by and optimized for firmware update and Trusted Invocation use cases, there is nothing in the SUIT Information Model {{RFC9124}} that restricts its use to only those use cases. Other use cases include the management of trusted applications (TAs) in a Trusted Execution Environment (TEE), as discussed in {{I-D.ietf-teep-architecture}}.

#  Conventions and Terminology

{::boilerplate bcp14-tagged}

Additionally, the following terminology is used throughout this document:

* SUIT: Software Update for the Internet of Things, also the IETF working group for this standard.
* Payload: A piece of information to be delivered. Typically Firmware for the purposes of SUIT.
* Resource: A piece of information that is used to construct a payload.
* Manifest: A manifest is a bundle of metadata about the firmware for an IoT device, where to
find the firmware, and the devices to which it applies.
* Envelope: A container with the manifest, an authentication wrapper with cryptographic information protecting the manifest, authorization information, and severable elements. Severable elements can be removed from the manifest without impacting its security, see {{severable-fields}}.
* Update: One or more manifests that describe one or more payloads.
* Update Authority: The owner of a cryptographic key used to sign updates, trusted by Recipients.
* Recipient: The system, typically an IoT device, that receives and processes a manifest.
* Manifest Processor: A component of the Recipient that consumes Manifests and executes the commands in the Manifest.
* Component: An updatable logical block of the Firmware, Software, configuration, or data of the Recipient.
* Component Set: A group of interdependent Components that must be updated simultaneously.
* Command: A Condition or a Directive.
* Condition: A test for a property of the Recipient or its Components.
* Directive: An action for the Recipient to perform.
* Trusted Invocation: A process by which a system ensures that only trusted code is executed, for example secure boot or launching a Trusted Application.
* A/B images: Dividing a Recipient's storage into two or more bootable images, at different offsets, such that the active image can write to the inactive image(s).
* Record: The result of a Command and any metadata about it.
* Report: A list of Records.
* Procedure: The process of invoking one or more sequences of commands.
* Update Procedure: A procedure that updates a Recipient by fetching dependencies and images, and installing them.
* Invocation Procedure: A procedure in which a Recipient verifies dependencies and images, loading images, and invokes one or more image.
* Software: Instructions and data that allow a Recipient to perform a useful function.
* Firmware: Software that is typically changed infrequently, stored in nonvolatile memory, and small enough to apply to {{RFC7228}} Class 0-2 devices.
* Image: Information that a Recipient uses to perform its function, typically firmware/software, configuration, or resource data such as text or images. Also, a Payload, once installed is an Image.
* Slot: One of several possible storage locations for a given Component, typically used in A/B image systems
* Abort: An event in which the Manifest Processor immediately halts execution of the current Procedure. It creates a Record of an error condition.

# How to use this Document

This specification covers five aspects of firmware update:

* {{background}} describes the device constraints, use cases, and design principles that informed the structure of the manifest.
* {{metadata-structure-overview}} gives a general overview of the metadata structure to inform the following sections
* {{interpreter-behavior}} describes what actions a Manifest processor should take.
* {{creating-manifests}} describes the process of creating a Manifest.
* {{metadata-structure}} specifies the content of the Envelope and the Manifest.

To implement an updatable device, see {{interpreter-behavior}} and {{metadata-structure}}.
To implement a tool that generates updates, see {{creating-manifests}} and {{metadata-structure}}.

The IANA consideration section, see {{iana}}, provides instructions to IANA to create several registries. This section also provides the CBOR labels for the structures defined in this document.

The complete CDDL description is provided in {{full-cddl}}, examples are given in {{examples}} and a design rational is offered in {{design-rationale}}. Finally, {{implementation-matrix}} gives a summarize of the mandatory-to-implement features of this specification.

Additional specifications describe functionality of advanced use cases, such as:

* Firmware Encryption is covered in {{I-D.ietf-suit-firmware-encryption}}
* Update Management is covered in {{I-D.ietf-suit-update-management}}
* Features, such as dependencies, key delegation, multiple processors, required by the use of multiple trust domains are covered in {{I-D.ietf-suit-trust-domains}}
* Secure reporting of the update status is covered in {{I-D.ietf-suit-report}}

A technique to efficiently compress firmware images may be standardized in the future.

# Background {#background}

Distributing software updates to diverse devices with diverse trust anchors in a coordinated system presents unique challenges. Devices have a broad set of constraints, requiring different metadata to make appropriate decisions. There may be many actors in production IoT systems, each of whom has some authority. Distributing firmware in such a multi-party environment presents additional challenges. Each party requires a different subset of data. Some data may not be accessible to all parties. Multiple signatures may be required from parties with different authorities. This topic is covered in more depth in {{RFC9019}}. The security aspects are described in {{RFC9124}}.

## IoT Firmware Update Constraints

The various constraints of IoT devices and the range of use cases that need to be supported create a broad set of requirements. For example, devices with:

* limited processing power and storage may require a simple representation of metadata.
* bandwidth constraints may require firmware compression or partial update support.
* bootloader complexity constraints may require simple selection between two bootable images.
* small internal storage may require external storage support.
* multiple microcontrollers may require coordinated update of all applications.
* large storage and complex functionality may require parallel update of many software components.
* extra information may need to be conveyed in the manifest in the earlier stages of the device lifecycle before those data items are stripped when the manifest is delivered to a constrained device.

Supporting the requirements introduced by the constraints on IoT devices requires the flexibility to represent a diverse set of possible metadata, but also requires that the encoding is kept simple.

##  SUIT Workflow Model

There are several fundamental assumptions that inform the model of Update Procedure workflow:

* Compatibility must be checked before any other operation is performed.
* In some applications, payloads must be fetched and validated prior to installation.

There are several fundamental assumptions that inform the model of the Invocation Procedure workflow:

* Compatibility must be checked before any other operation is performed.
* All payloads must be validated prior to loading.
* All loaded images must be validated prior to execution.

Based on these assumptions, the manifest is structured to work with a pull parser, where each section of the manifest is used in sequence. The expected workflow for a Recipient installing an update can be broken down into five steps:

1. Verify the signature of the manifest.
2. Verify the applicability of the manifest.
3. Fetch payload(s).
4. Install payload(s).
5. Verify image(s).

When installation is complete, similar information can be used for validating and invoking images in a further three steps:

6. Verify image(s).
7. Load image(s).
8. Invoke image(s).

If verification and invocation is implemented in a bootloader, then the bootloader MUST also verify the signature of the manifest and the applicability of the manifest in order to implement secure boot workflows. The bootloader may add its own authentication, e.g. a Message Authentication Code (MAC), to the manifest in order to prevent further verifications.

# Metadata Structure Overview {#metadata-structure-overview}

This section provides a high level overview of the manifest structure. The full description of the manifest structure is in {{manifest-structure}}

The manifest is structured from several key components:

1. The Envelope (see {{ovr-envelope}}) contains the Authentication Block, the Manifest, any Severable Elements, and any Integrated Payloads.
2. The Authentication Block (see {{ovr-auth}}) contains a list of signatures or MACs of the manifest.
3. The Manifest (see {{ovr-manifest}}) contains all critical, non-severable metadata that the Recipient requires. It is further broken down into:

    1. Critical metadata, such as sequence number.
    2. Common metadata, such as affected components.
    3. Command sequences, directing the Recipient how to install and use the payload(s).
    4. Integrity check values for severable elements.

5. Severable elements (see {{ovr-severable}}).
6. Integrated payloads (see {{ovr-integrated}}).

The diagram below illustrates the hierarchy of the Envelope.

~~~
+-------------------------+
| Envelope                |
+-------------------------+
| Authentication Block    |
| Manifest           --------------> +------------------------------+
| Severable Elements      |          | Manifest                     |
| Integrated Payloads     |          +------------------------------+
+-------------------------+          | Structure Version            |
                                     | Sequence Number              |
                                     | Reference to Full Manifest   |
                               +------ Common Structure             |
                               | +---- Command Sequences            |
+-------------------------+    | |   | Digests of Envelope Elements |
| Common Structure        | <--+ |   +------------------------------+
+-------------------------+      |
| Components IDs          |      +-> +-----------------------+
| Common Command Sequence ---------> | Command Sequence      |
+-------------------------+          +-----------------------+
                                     | List of ( pairs of (  |
                                     |   * command code      |
                                     |   * argument /        |
                                     |      reporting policy |
                                     | ))                    |
                                     +-----------------------+
~~~

## Envelope {#ovr-envelope}

The SUIT Envelope is a container that encloses the Authentication Block, the Manifest, any Severable Elements, and any integrated payloads. The Envelope is used instead of conventional cryptographic envelopes, such as COSE_Envelope because it allows modular processing, severing of elements, and integrated payloads in a way that avoids substantial complexity that would be needed with existing solutions. See {{design-rationale-envelope}} for a description of the reasoning for this.

See {{envelope}} for more detail.

## Authentication Block {#ovr-auth}

The Authentication Block contains a bstr-wrapped SUIT Digest Container, see {{SUIT_Digest}}, and one or more {{-cose}} CBOR Object Signing and Encryption (COSE) authentication blocks. These blocks are one of:

* COSE_Sign_Tagged
* COSE_Sign1_Tagged
* COSE_Mac_Tagged
* COSE_Mac0_Tagged

Each of these objects is used in detached payload mode. The payload is the bstr-wrapped SUIT_Digest.

See {{authentication-info}} for more detail.

## Manifest {#ovr-manifest}

The Manifest contains most metadata about one or more images. The Manifest is divided into Critical Metadata, Common Metadata, Command Sequences, and Integrity Check Values.

See {{manifest-structure}} for more detail.

### Critical Metadata {#ovr-critical}

Some metadata needs to be accessed before the manifest is processed. This metadata can be used to determine which manifest is newest and whether the structure version is supported. It also MAY provide a URI for obtaining a canonical copy of the manifest and Envelope.

See {{manifest-version}}, {{manifest-seqnr}}, and {{manifest-reference-uri}} for more detail.

### Common {#ovr-common}

Some metadata is used repeatedly and in more than one command sequence. In order to reduce the size of the manifest, this metadata is collected into the Common section. Common is composed of two parts: a list of components referenced by the manifest, and a command sequence to execute prior to each other command sequence. The common command sequence is typically used to set commonly used values and perform compatibility checks. The common command sequence MUST NOT have any side-effects outside of setting parameter values.

See {{manifest-common}} for more detail.

### Command Sequences {#ovr-commands}

Command sequences provide the instructions that a Recipient requires in order to install or use an image. These sequences tell a device to set parameter values, test system parameters, copy data from one place to another, transform data, digest data, and run code.

Command sequences are broken up into three groups: Common Command Sequence (see {{ovr-common}}), update commands, and secure boot commands.

Update Command Sequences are: Payload Fetch, Payload Installation and, System Validation. An Update Procedure is the complete set of each Update Command Sequence, each preceded by the Common Command Sequence.

Invocation Command Sequences are: System Validation, Image Loading, and Image Invocation. An Invocation Procedure is the complete set of each Invocation Command Sequence, each preceded by the Common Command Sequence.

Command Sequences are grouped into these sets to ensure that there is common coordination between dependencies and dependents on when to execute each command (dependencies are not defined in this specification).

See {{manifest-commands}} for more detail.

### Integrity Check Values {#ovr-integrity}

To enable severable elements {{ovr-severable}}, there needs to be a mechanism to verify the integrity of the severed data. While the severed data stays outside the manifest, for efficiency reasons, Integrity Check Values are used to include the digest of the data in the manifest. Note that Integrated Payloads, see {#ovr-integrated}, are integrity-checked using Command Sequences.

See {{integrity-checks}} for more detail.

### Human-Readable Text {#ovr-text}

Text is typically a Severable Element ({{ovr-severable}}). It contains all the text that describes the update. Because text is explicitly for human consumption, it is all grouped together so that it can be Severed easily. The text section has space both for describing the manifest as a whole and for describing each individual component.

See {{manifest-digest-text}} for more detail.

## Severable Elements {#ovr-severable}

Severable Elements are elements of the Envelope ({{ovr-envelope}}) that have Integrity Check Values ({{ovr-integrity}}) in the Manifest ({{ovr-manifest}}).

Because of this organisation, these elements can be discarded or "Severed" from the Envelope without changing the signature of the Manifest. This allows savings based on the size of the Envelope in several scenarios, for example:

* A management system severs the Text sections before sending an Envelope to a constrained Recipient, which saves Recipient bandwidth.
* A Recipient severs the Installation section after installing the Update, which saves storage space.

See {{severable-fields}} for more detail.

## Integrated Payloads {#ovr-integrated}

In some cases, it is beneficial to include a payload in the Envelope of a manifest. For example:

* When an update is delivered via a comparatively unconstrained medium, such as a removable mass storage device, it may be beneficial to bundle updates into single files.
* When a manifest transports a small payload, such as an encrypted key, that payload may be placed in the manifest's envelope.

See {{template-integrated-payload}} for more detail.

# Manifest Processor Behavior {#interpreter-behavior}

This section describes the behavior of the manifest processor and focuses primarily on interpreting commands in the manifest. However, there are several other important behaviors of the manifest processor: encoding version detection, rollback protection, and authenticity verification are chief among these.

## Manifest Processor Setup {#interpreter-setup}

Prior to executing any command sequence, the manifest processor or its host application MUST inspect the manifest version field and fail when it encounters an unsupported encoding version. Next, the manifest processor or its host application MUST extract the manifest sequence number and perform a rollback check using this sequence number. The exact logic of rollback protection may vary by application, but it has the following properties:

* Whenever the manifest processor can choose between several manifests, it MUST select the latest valid, authentic manifest.
* If the latest valid, authentic manifest fails, it MAY select the next latest valid, authentic manifest, according to application-specific policy.

Here, valid means that a manifest has a supported encoding version and it has not been excluded for other reasons. Reasons for excluding typically involve first executing the manifest and may include:

* Test failed (e.g. Vendor ID/Class ID).
* Unsupported command encountered.
* Unsupported parameter encountered.
* Unsupported Component Identifier encountered.
* Payload not available.
* Application crashed when executed.
* Watchdog timeout occurred.
* Payload verification failed.
* Missing required component from a Component Set.
* Required parameter not supplied.

These failure reasons MAY be combined with retry mechanisms prior to marking a manifest as invalid.

Selecting an older manifest in the event of failure of the latest valid manifest is one possible strategy to provide robustness of the firmware update process. It may not be appropriate for all applications. In particular Trusted Execution Environments MAY require a failure to invoke a new installation, rather than a rollback approach. See {{RFC9124, Section 4.2.1}} for more discussion on the security considerations that apply to rollback.

Following these initial tests, the manifest processor clears all parameter storage. This ensures that the manifest processor begins without any leaked data.

## Required Checks {#required-checks}

The RECOMMENDED process is to verify the signature of the manifest prior to parsing/executing any section of the manifest. This guards the parser against arbitrary input by unauthenticated third parties, but it costs extra energy when a Recipient receives an incompatible manifest.

When validating authenticity of manifests, the manifest processor MAY use an ACL (see {{access-control-lists}}) to determine the extent of the rights conferred by that authenticity.

Once a valid, authentic manifest has been selected, the manifest processor MUST examine the component list and
check that the number of components listed in the manifest is not larger than the number in the target system.

For each listed component, the manifest processor MUST provide storage for the supported parameters. If the manifest processor does not have sufficient temporary storage to process the parameters for all components, it MAY process components serially for each command sequence. See {{serial-processing}} for more details.

The manifest processor SHOULD check that the shared sequence contains at least Check Vendor Identifier command and at least one Check Class Identifier command.

Because the shared sequence contains Check Vendor Identifier and Check Class Identifier command(s), no custom commands are permitted in the shared sequence. This ensures that any custom commands are only executed by devices that understand them.

If the manifest contains more than one component, each command sequence MUST begin with a Set Component Index {{suit-directive-set-component-index}}.

If a Recipient supports groups of interdependent components (a Component Set), then it SHOULD verify that all Components in the Component Set are specified by one update, that is:

1. the manifest Author has sufficient permissions for the requested operations (see {{access-control-lists}}) and
2. the manifest specifies a digest and a payload for every Component in the Component Set.

### Minimizing Signature Verifications {#minimal-sigs}

Signature verification can be energy and time expensive on a constrained device. MAC verification is typically unaffected by these concerns. A Recipient MAY choose to parse and execute only the SUIT_Common section of the manifest prior to signature verification, if all of the below apply:

- The Authentication Block contains a COSE_Sign_Tagged or COSE_Sign1_Tagged
- The Recipient receives manifests over an unauthenticated channel, exposing it to more inauthentic or incompatible manifests, and
- The Recipient has a power budget that makes signature verification undesirable

When executing Common prior to authenticity validation, the Manifest Processor MUST first evaluate the integrity of the manifest using the SUIT_Digest present in the authentication block.

The guidelines in Creating Manifests ({{creating-manifests}}) require that the common section contains the applicability checks, so this section is sufficient for applicability verification. The parser MUST restrict acceptable commands to conditions and the following directives: Override Parameters, Set Parameters, Try Each, and Run Sequence ONLY. The manifest parser MUST NOT execute any command with side-effects outside the parser (for example, Run, Copy, Swap, or Fetch commands) prior to authentication and any such command MUST Abort. The Shared sequence MUST be executed again, in its entirety, after authenticity validation.

A Recipient MAY rely on network infrastructure to filter inapplicable manifests.

## Interpreter Fundamental Properties

The interpreter has a small set of design goals:

1. Executing an update MUST either result in an error, or a correct system state that can be checked against known digests.
2. Executing a Trusted Invocation MUST either result in an error, or an invoked image.
3. Executing the same manifest on multiple Recipients MUST result in the same system state.

NOTE: when using A/B images, the manifest functions as two (or more) logical manifests, each of which applies to a system in a particular starting state. With that provision, design goal 3 holds.

### Resilience to Disruption

As required in {{Section 3 of RFC9019}} and as an extension of design goal 1, devices must remain operable after a disruption, such as a power failure or network interruption, interrupts the update process.

The manifest processor must be resilient to these faults. In order to enable this resilience, systems implementing the manifest processor MUST make the following guarantees:

Either:
1. A fallback/recovery image is provided so that a disrupted system can apply the SUIT Manifest again.
2. Manifests are constructed so that repeated partial invocations of any manifest sequence always results in a correct system configuration.
3. A journal of manifest operations is stored in nonvolatile memory so that a repeated invocation does not alter nonvolatile memory up until the point of the previous failure. The journal enables the parser to recreate the processor state just prior to the disruption. This journal can be, for example, a SUIT Report. This report can be used to resume processing of the manifest from the point of failure.

AND

4. Where a command is not repeatable because of the way in which it alters system state (e.g. swapping images or in-place delta) it MUST be resumable or revertible. This applies to commands that modify at least one source component as well as the destination component.

## Abstract Machine Description {#command-behavior}

The heart of the manifest is the list of commands, which are processed by a Manifest Processor -- a form of interpreter. This Manifest Processor can be modeled as a simple abstract machine. This machine consists of several data storage locations that are modified by commands.

There are two types of commands, namely those that modify state (directives) and those that perform tests (conditions). Parameters are used as the inputs to commands. Some directives offer control flow operations. Directives target a specific component. A component is a unit of code or data that can be targeted by an update. Components are identified by Component Identifiers, but referenced in commands by Component Index; Component Identifiers are arrays of binary strings and a Component Index is an index into the array of Component Identifiers.

Conditions MUST NOT have any side-effects other than informing the interpreter of success or failure. The Interpreter does not Abort if the Soft Failure flag ({{suit-parameter-soft-failure}}) is set when a Condition reports failure.

Directives MAY have side-effects in the parameter table, the interpreter state, or the current component. The Interpreter MUST Abort if a Directive reports failure regardless of the Soft Failure flag.

To simplify the logic describing the command semantics, the object "current" is used. It represents the component identified by the Component Index:

~~~
current := components[component-index]
~~~

As a result, Set Component Index is described as current := components\[arg\].

The following table describes the behavior of each command. "params" represents the parameters for the current component. Most commands operate on a component.

| Command Name | Semantic of the Operation
|------|----
| Check Vendor Identifier | assert(binary-match(current, current.params\[vendor-id\]))
| Check Class Identifier | assert(binary-match(current, current.params\[class-id\]))
| Verify Image | assert(binary-match(digest(current), current.params\[digest\]))
| Check Content | assert(binary-match(current, current.params\[content\]))
| Set Component Index | current := components\[arg\]
| Override Parameters | current.params\[k\] := v for-each k,v in arg
| Set Parameters | current.params\[k\] := v if not k in params for-each k,v in arg
| Invoke  | invoke(current)
| Fetch | store(current, fetch(current.params\[uri\]))
| Write | store(current, current.params\[content\])
| Use Before  | assert(now() < arg)
| Check Component Slot  | assert(current.slot-index == arg)
| Check Device Identifier | assert(binary-match(current, current.params\[device-id\]))
| Abort | assert(0)
| Try Each  | try-each-done if exec(seq) is not error for-each seq in arg
| Copy | store(current, current.params\[src-component\])
| Swap | swap(current, current.params\[src-component\])
| Run Sequence | exec(arg)
| Invoke with Arguments | invoke(current, arg)

## Special Cases of Component Index {#index-true}

Component Index can take on one of three types:

1. Integer
2. Array of integers
3. True

Integers MUST always be supported by Set Component Index. Arrays of integers MUST be supported by Set Component Index if the Recipient supports 3 or more components. True MUST be supported by Set Component Index if the Recipient supports 2 or more components. Each of these operates on the list of components declared in the manifest.

Integer indices are the default case as described in the previous section. An array of integers represents a list of the components (Set Component Index) to which each subsequent command applies. The value True replaces the list of component indices with the full list of components, as defined in the manifest.

When a command is executed, it 

1. operates on the component identified by the component index if that index is an integer, or
2. it operates on each component identified by an array of indicies, or
3. it operates on every component if the index is the boolean True.

This is described by the following pseudocode:

~~~
if component-index is True:
    current-list = components
else if component-index is array:
    current-list = [ components[idx] for idx in component-index ]
else:
    current-list = [ components[component-index] ]
for current in current-list:
    cmd(current)
~~~

Try Each and Run Sequence are affected in the same way as other commands: they are invoked once for each possible Component. This means that the sequences that are arguments to Try Each and Run Sequence are not invoked with Component Index = True, nor are they invoked with array indices. They are only invoked with integer indices. The interpreter loops over the whole sequence, setting the Component Index to each index in turn.

## Serialized Processing Interpreter {#serial-processing}

In highly constrained devices, where storage for parameters is limited, the manifest processor MAY handle one component at a time, traversing the manifest tree once for each listed component. In this mode, the interpreter ignores any commands executed while the component index is not the current component. This reduces the overall volatile storage required to process the update so that the only limit on number of components is the size of the manifest. However, this approach requires additional processing power.

In order to operate in this mode, the manifest processor loops on each section for every supported component, simply ignoring commands when the current component is not selected.

When a serialized Manifest Processor encounters a component index of True, it does not ignore any commands. It applies them to the current component on each iteration.

## Parallel Processing Interpreter {#parallel-processing}

Advanced Recipients MAY make use of the Strict Order parameter and enable parallel processing of some Command Sequences, or it may reorder some Command Sequences. To perform parallel processing, once the Strict Order parameter is set to False, the Recipient may issue each or every command concurrently until the Strict Order parameter is returned to True or the Command Sequence ends. Then, it waits for all issued commands to complete before continuing processing of commands. To perform out-of-order processing, a similar approach is used, except the Recipient consumes all commands after the Strict Order parameter is set to False, then it sorts these commands into its preferred order, invokes them all, then continues processing.

When the manifest processor encounters any of these scenarios the parallel processing MUST halt until all issued commands have completed:

* Set Parameters.
* Override Parameters.
* Set Strict Order = True.
* Set Component Index.

To perform more useful parallel operations, a manifest author may collect sequences of commands in a Run Sequence command. Then, each of these sequences MAY be run in parallel. There are several invocation options for Run Sequence:

* Component Index is a positive integer, Strict Order is False: Strict Order is set to True before the sequence argument is run. The sequence argument MUST begin with set-component-index.
* Component Index is true or an array of positive integers, Strict Order is False: The sequence argument is run once for each component (or each component in the array); the manifest processor presets the component index and Strict Order = True before each iteration of the sequence argument.
* Component Index is a positive integer, Strict Order is True: No special considerations
* Component Index is True or an array of positive integers, Strict Order is True: The sequence argument is run once for each component (or each component in the array); the manifest processor presets the component index before each iteration of the sequence argument.

These rules isolate each sequence from each other sequence, ensuring that they operate as expected. When Strict Order = False, any further Set Component Index directives in the Run Sequence command sequence argument MUST cause an Abort. This allows the interpreter that issues Run Sequence commands to check that the first element is correct, then issue the sequence to a parallel execution context to handle the remainder of the sequence.

# Creating Manifests {#creating-manifests}

Manifests are created using tools for constructing COSE structures, calculating cryptographic values and compiling desired system state into a sequence of operations required to achieve that state. The process of constructing COSE structures and the calculation of cryptographic values is covered in {{-cose}}.

Compiling desired system state into a sequence of operations can be accomplished in many ways. Several templates are provided below to cover common use-cases. These templates can be combined to produce more complex behavior.

The author MUST ensure that all parameters consumed by a command are set prior to invoking that command. Where Component Index = True, this means that the parameters consumed by each command MUST have been set for each Component.

This section details a set of templates for creating manifests. These templates explain which parameters, commands, and orders of commands are necessary to achieve a stated goal.

NOTE: On systems that support only a single component, Set Component Index has no effect and can be omitted.

NOTE: **A digest MUST always be set using Override Parameters.**

## Compatibility Check Template {#template-compatibility-check}

The goal of the compatibility check template ensure that Recipients only install compatible images.

In this template all information is contained in the shared sequence and the following sequence of commands is used:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Override Parameters directive (see {{suit-directive-override-parameters}}) for Vendor ID and Class ID (see {{secparameters}})
- Check Vendor Identifier condition (see {{uuid-identifiers}})
- Check Class Identifier condition (see {{uuid-identifiers}})

## Trusted Invocation Template {#template-secure-boot}

The goal of the Trusted Invocation template is to ensure that only authorized code is invoked; such as in Secure Boot or when a Trusted Application is loaded into a TEE.

The following commands are placed into the shared sequence:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Override Parameters directive (see {{suit-directive-override-parameters}}) for Image Digest and Image Size (see {{secparameters}})

The system validation sequence contains the following commands:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Check Image Match condition (see {{suit-condition-image-match}})

Then, the run sequence contains the following commands:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Invoke directive (see {{suit-directive-invoke}})


## Component Download Template {#firmware-download-template}

The goal of the Component Download template is to acquire and store an image.

The following commands are placed into the shared sequence:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Override Parameters directive (see {{suit-directive-override-parameters}}) for Image Digest and Image Size (see {{secparameters}})

Then, the install sequence contains the following commands:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Override Parameters directive (see {{suit-directive-override-parameters}}) for URI (see {{suit-parameter-uri}})
- Fetch directive (see {{suit-directive-fetch}})
- Check Image Match condition (see {{suit-condition-image-match}})

The Fetch directive needs the URI parameter to be set to determine where the image is retrieved from. Additionally, the destination of where the component shall be stored has to be configured. The URI is configured via the Set Parameters directive while the destination is configured via the Set Component Index directive.

## Install Template {#template-install}

The goal of the Install template is to use an image already stored in an identified component to copy into a second component.

This template is typically used with the Component Download template, however a modification to that template is required: the Component Download operations are moved from the Payload Install sequence to the Payload Fetch sequence.

Then, the install sequence contains the following commands:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Override Parameters directive (see {{suit-directive-override-parameters}}) for Source Component (see {{suit-parameter-source-component}})
- Copy directive (see {{suit-directive-copy}})
- Check Image Match condition (see {{suit-condition-image-match}})

## Integrated Payload Template {#template-integrated-payload}

The goal of the Integrated Payload template is to install a payload that is included in the manifest envelope. It is identical to the Component Download template ({{firmware-download-template}}).

An implementer MAY choose to place a payload in the envelope of a manifest. The payload envelope key MUST be a string. The payload MUST be serialized in a bstr element.

The URI for a payload enclosed in this way MAY be expressed as a fragment-only reference, as defined in {{RFC3986, Section 4.4}}.

A distributor MAY choose to pre-fetch a payload and add it to the manifest envelope, using the URI as the key.

## Load from Nonvolatile Storage Template {#template-load-ext}

The goal of the Load from Nonvolatile Storage template is to load an image from a non-volatile component into a volatile component, for example loading a firmware image from external Flash into RAM.

The following commands are placed into the load sequence:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Override Parameters directive (see {{suit-directive-override-parameters}}) for Source Component (see {{secparameters}})
- Copy directive (see {{suit-directive-copy}})

As outlined in {{command-behavior}}, the Copy directive needs a source and a destination to be configured. The source is configured via Component Index (with the Set Parameters directive) and the destination is configured via the Set Component Index directive.

## A/B Image Template {#a-b-template}

The goal of the A/B Image Template is to acquire, validate, and invoke one of two images, based on a test.

The following commands are placed in the common block:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Try Each
    - First Sequence:
        - Override Parameters directive (see {{suit-directive-override-parameters}}, {{secparameters}}) for Slot A
        - Check Slot Condition (see {{suit-condition-component-slot}})
        - Override Parameters directive (see {{suit-directive-override-parameters}}) for Image Digest A and Image Size A (see {{secparameters}})
    - Second Sequence:
        - Override Parameters directive (see {{suit-directive-override-parameters}}, {{secparameters}}) for Slot B
        - Check Slot Condition (see {{suit-condition-component-slot}})
        - Override Parameters directive (see {{suit-directive-override-parameters}}) for Image Digest B and Image Size B (see {{secparameters}})

The following commands are placed in the fetch block or install block

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Try Each
    - First Sequence:
        - Override Parameters directive (see {{suit-directive-override-parameters}}, {{secparameters}}) for Slot A
        - Check Slot Condition (see {{suit-condition-component-slot}})
        - Set Parameters directive (see {{suit-directive-override-parameters}}) for URI A (see {{secparameters}})
    - Second Sequence:
        - Override Parameters directive (see {{suit-directive-override-parameters}}, {{secparameters}}) for Slot B
        - Check Slot Condition (see {{suit-condition-component-slot}})
        - Set Parameters directive (see {{suit-directive-override-parameters}}) for URI B (see {{secparameters}})
- Fetch

If Trusted Invocation ({{template-secure-boot}}) is used, only the run sequence is added to this template, since the shared sequence is populated by this template:

- Set Component Index directive (see {{suit-directive-set-component-index}})
- Try Each
    - First Sequence:
        - Override Parameters directive (see {{suit-directive-override-parameters}}, {{secparameters}}) for Slot A
        - Check Slot Condition (see {{suit-condition-component-slot}})
    - Second Sequence:
        - Override Parameters directive (see {{suit-directive-override-parameters}}, {{secparameters}}) for Slot B
        - Check Slot Condition (see {{suit-condition-component-slot}})
- Invoke

NOTE: Any test can be used to select between images, Check Slot Condition is used in this template because it is a typical test for execute-in-place devices.

# Metadata Structure {#metadata-structure}

The metadata for SUIT updates is composed of several primary constituent parts: Authentication Information, Manifest, Severable Elements and Integrated Payloads.

For a diagram of the metadata structure, see {{metadata-structure-overview}}.

## Encoding Considerations

The map indices in the envelope encoding are reset to 1 for each map within the structure. This is to keep the indices as small as possible. The goal is to keep the index objects to single bytes (CBOR positive integers 1-23).

Wherever enumerations are used, they are started at 1. This allows detection of several common software errors that are caused by uninitialized variables. Positive numbers in enumerations are reserved for IANA registration. Negative numbers are used to identify application-specific values, as described in {{iana}}.

All elements of the envelope must be wrapped in a bstr to minimize the complexity of the code that evaluates the cryptographic integrity of the element and to ensure correct serialization for integrity and authenticity checks.

All CBOR maps in the Manifest and manifest envelope MUST be encoded with the canonical CBOR ordering as defined in {{RFC8949}}.

## Envelope {#envelope}

The Envelope contains each of the other primary constituent parts of the SUIT metadata. It allows for modular processing of the manifest by ordering components in the expected order of processing.

The Envelope is encoded as a CBOR Map. Each element of the Envelope is enclosed in a bstr, which allows computation of a message digest against known bounds.

## Authenticated Manifests {#authentication-info}

SUIT_Authentication contains a list of elements, which consist of a SUIT_Digest calculated over the manifest, and zero or more SUIT_Authentication_Block's calculated over the SUIT_Digest.

~~~
SUIT_Authentication = [
    bstr .cbor SUIT_Digest,
    * bstr .cbor SUIT_Authentication_Block
]
SUIT_Authentication_Block /= COSE_Mac_Tagged
SUIT_Authentication_Block /= COSE_Sign_Tagged
SUIT_Authentication_Block /= COSE_Mac0_Tagged
SUIT_Authentication_Block /= COSE_Sign1_Tagged
~~~

The SUIT_Digest is computed over the bstr-wrapped SUIT_Manifest that is present in the SUIT_Envelope at the suit-manifest key. The SUIT_Digest MUST always be present. The Manifest Processor requires a SUIT_Authentication_Block to be present. The manifest MUST be protected from tampering between the time of creation and the time of signing/MACing.

The SUIT_Authentication_Block is computed using detached payloads, as described in RFC 9052 {{-cose}}. The detached payload in each case is the bstr-wrapped SUIT_Digest at the beginning of the list. Signers (or MAC calculators) MUST verify the SUIT_Digest prior to performing the cryptographic computation to avoid "Time-of-check to time-of-use" type of attack. When multiple SUIT_Authentication_Blocks are present, then each  SUIT_Authentication_Block MUST be computed over the same SUIT_Digest but using a different algorithm or signing/MAC authority. This feature also allows to transition to new algorithms, such as post-quantum cryptography (PQC) algorithms.

The SUIT_Authentication structure MUST come before the suit-manifest element, regardless of canonical encoding of CBOR. The algorithms used in SUIT_Authentication are defined by the profiles declared in {{I-D.moran-suit-mti}}.

## Manifest {#manifest-structure}

The manifest contains:

- a version number (see {{manifest-version}})
- a sequence number (see {{manifest-seqnr}})
- a reference URI (see {{manifest-reference-uri}})
- a common structure with information that is shared between command sequences (see {{manifest-common}})
- one or more lists of commands that the Recipient should perform (see {{manifest-commands}})
- a reference to the full manifest (see {{manifest-reference-uri}})
- human-readable text describing the manifest found in the SUIT_Envelope (see {{manifest-digest-text}})

The Text section, or any Command Sequence of the Update Procedure (Image Fetch, Image Installation and, System Validation) can be either a CBOR structure or a SUIT_Digest. In each of these cases, the SUIT_Digest provides for a severable element. Severable elements are RECOMMENDED to implement. In particular, the human-readable text SHOULD be severable, since most useful text elements occupy more space than a SUIT_Digest, but are not needed by the Recipient. Because SUIT_Digest is a CBOR Array and each severable element is a CBOR bstr, it is straight-forward for a Recipient to determine whether an element has been severed. The key used for a severable element is the same in the SUIT_Manifest and in the SUIT_Envelope so that a Recipient can easily identify the correct data in the envelope. See {{integrity-checks}} for more detail.

### suit-manifest-version {#manifest-version}

The suit-manifest-version indicates the version of serialization used to encode the manifest. Version 1 is the version described in this document. suit-manifest-version is REQUIRED to implement.

### suit-manifest-sequence-number {#manifest-seqnr}

The suit-manifest-sequence-number is a monotonically increasing anti-rollback counter. Each Recipient MUST reject any manifest that has a sequence number lower than its current sequence number. For convenience, an implementer MAY use a UTC timestamp in seconds as the sequence number. suit-manifest-sequence-number is REQUIRED to implement.

### suit-reference-uri {#manifest-reference-uri}

suit-reference-uri is a text string that encodes a URI where a full version of this manifest can be found. This is convenient for allowing management systems to show the severed elements of a manifest when this URI is reported by a Recipient after installation.

### suit-text {#manifest-digest-text}

suit-text SHOULD be a severable element. suit-text is a map of language identifiers (identical to Tag38 of RFC9290, Appendix A) to language-specific text maps. Each language-specific text map is a map containing two different types of pair:

* integer => text
* SUIT_Component_Identifier => map

The SUIT_Text_Map is defined in the following CDDL.

~~~
tag38-ltag = text .regexp "[a-zA-Z]{1,8}(-[a-zA-Z0-9]{1,8})*"

SUIT_Text_Map = {
    + tag38-ltag => SUIT_Text_LMap
}
SUIT_Text_LMap = {
    SUIT_Text_Keys,
    * SUIT_Component_Identifier => {
        SUIT_Text_Component_Keys
    }
}
~~~

Each SUIT_Component_Identifier => map entry contains a map of integer => text values. All SUIT_Component_Identifiers present in suit-text MUST also be present in suit-common ({{manifest-common}}).

suit-text contains all the human-readable information that describes any and all parts of the manifest, its payload(s) and its resource(s). The text section is typically severable, allowing manifests to be distributed without the text, since end-nodes do not require text. The meaning of each field is described below.

Each section MAY be present. If present, each section MUST be as described. Negative integer IDs are reserved for application-specific text values.

The following table describes the text fields available in suit-text:

CDDL Structure | Description
---|---
suit-text-manifest-description | Free text description of the manifest
suit-text-update-description | Free text description of the update
suit-text-manifest-json-source | The JSON-formatted document that was used to create the manifest
suit-text-manifest-yaml-source | The YAML {{YAML}}-formatted document that was used to create the manifest

The following table describes the text fields available in each map identified by a SUIT_Component_Identifier.

CDDL Structure | Description
---|---
suit-text-vendor-name | Free text vendor name
suit-text-model-name | Free text model name
suit-text-vendor-domain | The domain used to create the vendor-id condition (see {{uuid-identifiers}})
suit-text-model-info | The information used to create the class-id condition (see {{uuid-identifiers)
suit-text-component-description | Free text description of each component in the manifest
suit-text-component-version | A free text representation of the component version

suit-text is OPTIONAL to implement.

### suit-common {#manifest-common}

suit-common encodes all the information that is shared between each of the command sequences, including: suit-components, and suit-shared-sequence. suit-common is REQUIRED to implement.

suit-components is a list of [SUIT_Component_Identifier](#suit-component-identifier) blocks that specify the component identifiers that will be affected by the content of the current manifest. suit-components is REQUIRED to implement.

suit-shared-sequence is a SUIT_Command_Sequence to execute prior to executing any other command sequence. Typical actions in suit-shared-sequence include setting expected Recipient identity and image digests when they are conditional (see {{suit-directive-try-each}} and {{a-b-template}} for more information on conditional sequences). suit-shared-sequence is RECOMMENDED to implement. It is REQUIRED if the optimizations described in {{minimal-sigs}} will be used. Whenever a parameter or Try Each command is required by more than one Command Sequence, placing that parameter or command in suit-shared-sequence results in a smaller encoding.

#### SUIT_Component_Identifier {#suit-component-identifier}

A component is a unit of code or data that can be targeted by an update. To facilitate composite devices, components are identified by a list of CBOR byte strings, which allows construction of hierarchical component structures. Components are identified by Component Identifiers, but referenced in commands by Component Index; Component Identifiers are arrays of binary strings and a Component Index is an index into the array of Component Identifiers.

A Component Identifier can be trivial, such as the simple array \[h'00'\]. It can also represent a filesystem path by encoding each segment of the path as an element in the list. For example, the path "/usr/bin/env" would encode to \['usr','bin','env'\].

This hierarchical construction allows a component identifier to identify any part of a complex, multi-component system.

### SUIT_Command_Sequence {#manifest-commands}

A SUIT_Command_Sequence defines a series of actions that the Recipient MUST take to accomplish a particular goal. These goals are defined in the manifest and include:

1. Payload Fetch: suit-payload-fetch is a SUIT_Command_Sequence to execute in order to obtain a payload. Some manifests may include these actions in the suit-install section instead if they operate in a streaming installation mode. This is particularly relevant for constrained devices without any temporary storage for staging the update. suit-payload-fetch is OPTIONAL to implement.

2. Payload Installation: suit-install is a SUIT_Command_Sequence to execute in order to install a payload. Typical actions include verifying a payload stored in temporary storage, copying a staged payload from temporary storage, and unpacking a payload. suit-install is OPTIONAL to implement.

3. Image Validation: suit-validate is a SUIT_Command_Sequence to execute in order to validate that the result of applying the update is correct. Typical actions involve image validation. suit-validate is REQUIRED to implement.

4. Image Loading: suit-load is a SUIT_Command_Sequence to execute in order to prepare a payload for execution. Typical actions include copying an image from permanent storage into RAM, optionally including actions such as decryption or decompression. suit-load is OPTIONAL to implement.

5. Invoke or Boot: suit-invoke is a SUIT_Command_Sequence to execute in order to invoke an image. suit-invoke typically contains a single instruction: the "invoke" directive, but may also contain an image condition. suit-invoke is OPTIONAL to implement.

Goals 1,2,3 form the Update Procedure. Goals 3,4,5 form the Invocation Procedure.

Each Command Sequence follows exactly the same structure to ensure that the parser is as simple as possible.

Lists of commands are constructed from two kinds of element:

1. Conditions that MUST be true and any failure is treated as a failure of the update/load/invocation
2. Directives that MUST be executed.

Each condition is composed of:

1. A command code identifier
2. A [SUIT_Reporting_Policy](#reporting-policy)

Each directive is composed of:

1. A command code identifier
2. An argument block or a [SUIT_Reporting_Policy](#reporting-policy)

Argument blocks are consumed only by flow-control directives:

* Set Component Index
* Set/Override Parameters
* Try Each
* Run Sequence

Reporting policies provide a hint to the manifest processor of whether to add the success or failure of a command to any report that it generates.

Many conditions and directives apply to a given component, and these generally grouped together. Therefore, a special command to set the current component index is provided. This index is a numeric index into the Component Identifier table defined at the beginning of the manifest.

To facilitate optional conditions, a special directive, suit-directive-try-each ({{suit-directive-try-each}}), is provided. It runs several new lists of conditions/directives, one after another, that are contained as an argument to the directive. By default, it assumes that a failure of a condition should not indicate a failure of the update/invocation, but a parameter is provided to override this behavior. See suit-parameter-soft-failure ({{suit-parameter-soft-failure}}).

### Reporting Policy {#reporting-policy}

To facilitate construction of Reports that describe the success or failure of a given Procedure, each command is given a Reporting Policy. This is an integer bitfield that follows the command and indicates what the Recipient should do with the Record of executing the command. The options are summarized in the table below.

Policy | Description
---|---
suit-send-record-on-success | Record when the command succeeds
suit-send-record-on-failure | Record when the command fails
suit-send-sysinfo-success | Add system information when the command succeeds
suit-send-sysinfo-failure | Add system information when the command fails

Any or all of these policies may be enabled at once.

At the completion of each command, a Manifest Processor MAY forward information about the command to a Reporting Engine, which is responsible for reporting boot or update status to a third party. The Reporting Engine is entirely implementation-defined, the reporting policy simply facilitates the Reporting Engine's interface to the SUIT Manifest Processor.

The information elements provided to the Reporting Engine are:

- The reporting policy
- The result of the command
- The values of parameters consumed by the command
- The system information consumed by the command

The Reporting Engine consumes these information elements and decides whether to generate an entry in its report output and which information elements to include based on its internal policy decisions. The Reporting Engine uses the reporting policy provided to it by the SUIT Manifest Processor as a set of hints but MAY choose to ignore these hints and apply its own policy instead.

If the component index is set to True or an array when a command is executed with a non-zero reporting policy, then the Reporting Engine MUST receive one set of information elements for each Component, in the order expressed in the Components list or the Component Index array.

This specification does not define a particular format of Records or Reports. This specification only defines hints to the Reporting Engine for which information elements it should aggregate into the Report.

When used in a Invocation Procedure, the output of the Reporting Engine MAY form the basis of an attestation report. When used in an Update Process, the report MAY form the basis for one or more log entries.

### SUIT_Parameters {#secparameters}

Many conditions and directives require additional information. That information is contained within parameters that can be set in a consistent way. This allows reuse of parameters between commands, thus reducing manifest size.

Most parameters are scoped to a specific component. This means that setting a parameter for one component has no effect on the parameters of any other component. The only exceptions to this are two Manifest Processor parameters: Strict Order and Soft Failure.

The defined manifest parameters are described below.

Name | CDDL Structure | Reference
---|---|---
Vendor ID | suit-parameter-vendor-identifier | {{suit-parameter-vendor-identifier}}
Class ID | suit-parameter-class-identifier | {{suit-parameter-class-identifier}}
Device ID | suit-parameter-device-identifier | {{suit-parameter-device-identifier}}
Image Digest | suit-parameter-image-digest | {{suit-parameter-image-digest}}
Image Size | suit-parameter-image-size | {{suit-parameter-image-size}}
Content | suit-parameter-content | {{suit-parameter-content}}
Component Slot | suit-parameter-component-slot | {{suit-parameter-component-slot}}
URI | suit-parameter-uri | {{suit-parameter-uri}}
Source Component | suit-parameter-source-component | {{suit-parameter-source-component}}
Invoke Args | suit-parameter-invoke-args | {{suit-parameter-invoke-args}}
Fetch Arguments | suit-parameter-fetch-arguments | {{suit-parameter-fetch-arguments}}
Strict Order | suit-parameter-strict-order | {{suit-parameter-strict-order}}
Soft Failure | suit-parameter-soft-failure | {{suit-parameter-soft-failure}}
Custom | suit-parameter-custom | {{suit-parameter-custom}}

CBOR-encoded object parameters are still wrapped in a bstr. This is because it allows a parser that is aggregating parameters to reference the object with a single pointer and traverse it without understanding the contents. This is important for modularization and division of responsibility within a pull parser. The same consideration does not apply to Directives because those elements are invoked with their arguments immediately.

#### CBOR PEN UUID Namespace Identifier

The CBOR PEN UUID Namespace Identifier is constructed as follows:

It uses the OID Namespace as a starting point, then uses the CBOR absolute OID encoding for the IANA PEN OID (1.3.6.1.4.1):

~~~
D8 6F                # tag(111)
   45                # bytes(5)
# Absolute OID encoding of IANA Private Enterprise Number:
#    1.3. 6. 1. 4. 1
      2B 06 01 04 01 # X.690 Clause 8.19
~~~

Computing a version 5 UUID from these produces:

~~~
NAMESPACE_CBOR_PEN = UUID5(NAMESPACE_OID, h'D86F452B06010401')
NAMESPACE_CBOR_PEN = 47fbdabb-f2e4-55f0-bb39-3620c2f6df4e
~~~

#### Constructing UUIDs {#uuid-identifiers}

Several conditions use identifiers to determine whether a manifest matches a given Recipient or not. These identifiers are defined to be RFC 4122 {{RFC4122}} UUIDs. These UUIDs are not human-readable and are therefore used for machine-based processing only.

A Recipient MAY match any number of UUIDs for vendor or class identifier. This may be relevant to physical or software modules. For example, a Recipient that has an OS and one or more applications might list one Vendor ID for the OS and one or more additional Vendor IDs for the applications. This Recipient might also have a Class ID that must be matched for the OS and one or more Class IDs for the applications.

Identifiers are used for compatibility checks. They MUST NOT be used as assertions of identity. They are evaluated by identifier conditions ({{identifier-conditions}}).

A more complete example: Imagine a device has the following physical components:
1. A host MCU
2. A WiFi module

This same device has three software modules:
1. An operating system
2. A WiFi module interface driver
3. An application

Suppose that the WiFi module's firmware has a proprietary update mechanism and doesn't support manifest processing. This device can report four class IDs:

1. Hardware model/revision
2. OS
3. WiFi module model/revision
4. Application

This allows the OS, WiFi module, and application to be updated independently. To combat possible incompatibilities, the OS class ID can be changed each time the OS has a change to its API.

This approach allows a vendor to target, for example, all devices with a particular WiFi module with an update, which is a very powerful mechanism, particularly when used for security updates.

UUIDs MUST be created according to versions 3, 4, or 5 of RFC 4122 {{RFC4122}}. Versions 1 and 2 do not provide a tangible benefit over version 4 for this application.

The RECOMMENDED method to create a vendor ID is:

~~~
Vendor ID = UUID5(DNS_PREFIX, vendor domain name)
~~~

If the Vendor ID is a UUID, the RECOMMENDED method to create a Class ID is:

~~~
Class ID = UUID5(Vendor ID, Class-Specific-Information)
~~~

If the Vendor ID is a CBOR PEN (see {{suit-parameter-vendor-identifier}}), the RECOMMENDED method to create a Class ID is:

~~~
Class ID = UUID5(
    UUID5(NAMESPACE_CBOR_PEN, CBOR_PEN),
    Class-Specific-Information)
~~~


Class-specific-information is composed of a variety of data, for example:

* Model number.
* Hardware revision.
* Bootloader version (for immutable bootloaders).

#### suit-parameter-vendor-identifier {#suit-parameter-vendor-identifier}

suit-parameter-vendor-identifier may be presented in one of two ways:

- A Private Enterprise Number
- A byte string containing a UUID {{RFC4122}}

Private Enterprise Numbers are encoded as a relative OID, according to the definition in {{-oid}}. All PENs are relative to the IANA PEN: 1.3.6.1.4.1.

#### suit-parameter-class-identifier {#suit-parameter-class-identifier}

A RFC 4122 UUID representing the class of the device or component. The UUID is encoded as a 16 byte bstr, containing the raw bytes of the UUID. It MUST be constructed as described in {{uuid-identifiers}}

#### suit-parameter-device-identifier {#suit-parameter-device-identifier}

A RFC 4122 UUID representing the specific device or component. The UUID is encoded as a 16 byte bstr, containing the raw bytes of the UUID. It MUST be constructed as described in {{uuid-identifiers}}

#### suit-parameter-image-digest {#suit-parameter-image-digest}

A fingerprint computed over the component itself, encoded in the SUIT_Digest {{SUIT_Digest}} structure. The SUIT_Digest is wrapped in a bstr, as required in {{secparameters}}.

#### suit-parameter-image-size {#suit-parameter-image-size}

The size of the firmware image in bytes. This size is encoded as a positive integer.

#### suit-parameter-component-slot {#suit-parameter-component-slot}

This parameter sets the slot index of a component. Some components support multiple possible Slots (offsets into a storage area). This parameter describes the intended Slot to use, identified by its index into the component's storage area. This slot MUST be encoded as a positive integer.

#### suit-parameter-content {#suit-parameter-content}

A block of raw data for use with {{suit-directive-write}}. It contains a byte string of data to be written to a specified component ID in the same way as a fetch or a copy.

If data is encoded this way, it should be small, e.g. 10's of bytes. Large payloads, e.g. 1000's of bytes, written via this method might prevent the manifest from being held in memory during validation. Typical applications include small configuration parameters.

The size of payload embedded in suit-parameter-content impacts the security requirement defined in {{RFC9124}}, Section 4.3.21 REQ.SEC.MFST.CONST: Manifest Kept Immutable between Check and Use. Actual limitations on payload size for suit-parameter-content depend on the application, in particular the available memory that satisfies REQ.SEC.MFST.CONST. If the availability of tamper resistant memory is less than the manifest size, then REQ.SEC.MFST.CONST cannot be satisfied.

If suit-parameter-content is instantiated in a severable command sequence, then this becomes functionally very similar to an integrated payload, which may be a better choice.

#### suit-parameter-uri {#suit-parameter-uri}

A URI Reference {{RFC3986}} from which to fetch a resource, encoded as a text string. CBOR Tag 32 is not used because the meaning of the text string is unambiguous in this context.

#### suit-parameter-source-component {#suit-parameter-source-component}

This parameter sets the source component to be used with either suit-directive-copy ({{suit-directive-copy}}) or with suit-directive-swap ({{suit-directive-swap}}). The current Component, as set by suit-directive-set-component-index defines the destination, and suit-parameter-source-component defines the source.

#### suit-parameter-invoke-args {#suit-parameter-invoke-args}

This parameter contains an encoded set of arguments for suit-directive-invoke ({{suit-directive-invoke}}). The arguments MUST be provided as an implementation-defined bstr.

#### suit-parameter-fetch-arguments

An implementation-defined set of arguments to suit-directive-fetch ({{suit-directive-fetch}}). Arguments are encoded in a bstr.

#### suit-parameter-strict-order

The Strict Order Parameter allows a manifest to govern when directives can be executed out-of-order. This allows for systems that have a sensitivity to order of updates to choose the order in which they are executed. It also allows for more advanced systems to parallelize their handling of updates. Strict Order defaults to True. It MAY be set to False when the order of operations does not matter. When arriving at the end of a command sequence, ALL commands MUST have completed, regardless of the state of SUIT_Parameter_Strict_Order. If SUIT_Parameter_Strict_Order is returned to True, ALL preceding commands MUST complete before the next command is executed.

See {{parallel-processing}} for behavioral description of Strict Order.

#### suit-parameter-soft-failure

When executing a command sequence inside suit-directive-try-each ({{suit-directive-try-each}}) or suit-directive-run-sequence ({{suit-directive-run-sequence}}) and a condition failure occurs, the manifest processor aborts the sequence. For suit-directive-try-each, if Soft Failure is True, the next sequence in Try Each is invoked, otherwise suit-directive-try-each fails with the condition failure code. In suit-directive-run-sequence, if Soft Failure is True the suit-directive-run-sequence simply halts with no side-effects and the Manifest Processor continues with the following command, otherwise, the suit-directive-run-sequence fails with the condition failure code.

suit-parameter-soft-failure is scoped to the enclosing SUIT_Command_Sequence. Its value is discarded when SUIT_Command_Sequence terminates. It MUST NOT be set outside of suit-directive-try-each or suit-directive-run-sequence.

When suit-directive-try-each is invoked, Soft Failure defaults to True. An Update Author may choose to set Soft Failure to False if they require a failed condition in a sequence to force an Abort.

When suit-directive-run-sequence is invoked, Soft Failure defaults to False. An Update Author may choose to make failures soft within a suit-directive-run-sequence.

#### suit-parameter-custom

This parameter is an extension point for any proprietary, application specific conditions and directives. It MUST NOT be used in the shared sequence. This effectively scopes each custom command to a particular Vendor Identifier/Class Identifier pair.

### SUIT_Condition

Conditions are used to define mandatory properties of a system in order for an update to be applied. They can be pre-conditions or post-conditions of any directive or series of directives, depending on where they are placed in the list. All Conditions specify a Reporting Policy as described {{reporting-policy}}. Conditions include:

 Name | CDDL Structure | Reference
---|---|---
Vendor Identifier | suit-condition-vendor-identifier | {{identifier-conditions}}
Class Identifier | suit-condition-class-identifier | {{identifier-conditions}}
Device Identifier | suit-condition-device-identifier | {{identifier-conditions}}
Image Match | suit-condition-image-match | {{suit-condition-image-match}}
Check Content | suit-condition-check-content | {{suit-condition-check-content}}
Component Slot | suit-condition-component-slot | {{suit-condition-component-slot}}
Abort | suit-condition-abort | {{suit-condition-abort}}
Custom Condition | suit-condition-custom | {{SUIT_Condition_Custom}}

The abstract description of these conditions is defined in {{command-behavior}}.

Conditions compare parameters against properties of the system. These properties may be asserted in many different ways, including: calculation on-demand, volatile definition in memory, static definition within the manifest processor, storage in known location within an image, storage within a key storage system, storage in One-Time-Programmable memory, inclusion in mask ROM, or inclusion as a register in hardware. Some of these assertion methods are global in scope, such as a hardware register, some are scoped to an individual component, such as storage at a known location in an image, and some assertion methods can be either global or component-scope, based on implementation.

Each condition MUST report a result code on completion. If a condition reports failure, then the current sequence of commands MUST terminate. A subsequent command or command sequence MAY continue executing if suit-parameter-soft-failure ({{suit-parameter-soft-failure}}) is set. If a condition requires additional information, this MUST be specified in one or more parameters before the condition is executed. If a Recipient attempts to process a condition that expects additional information and that information has not been set, it MUST report a failure. If a Recipient encounters an unknown condition, it MUST report a failure.

Condition labels in the positive number range are reserved for IANA registration while those in the negative range are custom conditions reserved for proprietary definition by the author of a manifest processor. See {{iana}} for more details.

#### suit-condition-vendor-identifier, suit-condition-class-identifier, and suit-condition-device-identifier {#identifier-conditions}

There are three identifier-based conditions: suit-condition-vendor-identifier, suit-condition-class-identifier, and suit-condition-device-identifier. Each of these conditions match a RFC 4122 {{RFC4122}} UUID that MUST have already been set as a parameter. The installing Recipient MUST match the specified UUID in order to consider the manifest valid. These identifiers are scoped by component in the manifest. Each component MAY match more than one identifier. Care is needed to ensure that manifests correctly identify their targets using these conditions. Using only a generic class ID for a device-specific firmware could result in matching devices that are not compatible.

The Recipient uses the ID parameter that has already been set using the Set Parameters directive. If no ID has been set, this condition fails. suit-condition-class-identifier and suit-condition-vendor-identifier are REQUIRED to implement. suit-condition-device-identifier is OPTIONAL to implement.

Each identifier condition compares the corresponding identifier parameter to a parameter asserted to the Manifest Processor by the Recipient. Identifiers MUST be known to the Manifest Processor in order to evaluate compatibility.

#### suit-condition-image-match

Verify that the current component matches the suit-parameter-image-digest ({{suit-parameter-image-digest}}) for the current component. The digest is verified against the digest specified in the Component's parameters list. If no digest is specified, the condition fails. suit-condition-image-match is REQUIRED to implement.

#### suit-condition-check-content {#suit-condition-check-content}

This directive compares the specified component identifier to the data indicated by suit-parameter-content. This functions similarly to suit-condition-image-match, however it does a direct, byte-by-byte comparison rather than a digest-based comparison. Because it is possible that an early stop to check-content could reveal information through timing, suit-condition-check-content MUST be constant time: no early exits. 

The following pseudo-code described an example content checking algorithm:

~~~
// content & component must be same length
// returns 0 for match
int check_content(content, component, length) {
    int residual = 0;
    for (i = 0; i < length; i++) {
        residual |= content[i] ^ component[i];
    }
    return residual;
}
~~~

#### suit-condition-component-slot {#suit-condition-component-slot}

Verify that the slot index of the current component matches the slot index set in suit-parameter-component-slot ({{suit-parameter-component-slot}}). This condition allows a manifest to select between several images to match a target slot.

#### suit-condition-abort {#suit-condition-abort}

Unconditionally fail. This operation is typically used in conjunction with suit-directive-try-each ({{suit-directive-try-each}}).

#### suit-condition-custom {#SUIT_Condition_Custom}

suit-condition-custom describes any proprietary, application specific condition. This is encoded as a negative integer, chosen by the firmware developer. If additional information must be provided to the condition, it should be encoded in a custom parameter (a nint) as described in {{secparameters}}. SUIT_Condition_Custom is OPTIONAL to implement.

### SUIT_Directive
Directives are used to define the behavior of the recipient. Directives include:

Name | CDDL Structure | Reference
---|---|---
Set Component Index | suit-directive-set-component-index | {{suit-directive-set-component-index}}
Try Each | suit-directive-try-each | {{suit-directive-try-each}}
Override Parameters | suit-directive-override-parameters | {{suit-directive-override-parameters}}
Fetch | suit-directive-fetch | {{suit-directive-fetch}}
Copy | suit-directive-copy | {{suit-directive-copy}}
Write | suit-directive-write | {{suit-directive-write}}
Invoke | suit-directive-invoke | {{suit-directive-invoke}}
Run Sequence | suit-directive-run-sequence | {{suit-directive-run-sequence}}
Swap | suit-directive-swap | {{suit-directive-swap}}

The abstract description of these commands is defined in {{command-behavior}}.

When a Recipient executes a Directive, it MUST report a result code. If the Directive reports failure, then the current Command Sequence MUST be terminated.

#### suit-directive-set-component-index {#suit-directive-set-component-index}

Set Component Index defines the component to which successive directives and conditions will apply. The Set Component Index arguments are described in {{index-true}}.

If the following commands apply to ONE component, an unsigned integer index into the component list is used. If the following commands apply to ALL components, then the boolean value "True" is used instead of an index. If the following commands apply to more than one, but not all components, then an array of unsigned integer indices into the component list is used.

If component index is set to True when a command is invoked, then the command applies to all components, in the order they appear in suit-common-components. When the Manifest Processor invokes a command while the component index is set to True, it must execute the command once for each possible component index, ensuring that the command receives the parameters corresponding to that component index.

#### suit-directive-try-each {#suit-directive-try-each}

This command runs several SUIT_Command_Sequence instances, one after another, in a strict order, until one succeeds or the list is exhausted. Use this command to implement a "try/catch-try/catch" sequence. Manifest processors MAY implement this command.

suit-parameter-soft-failure ({{suit-parameter-soft-failure}}) is initialized to True at the beginning of each sequence. If one sequence aborts due to a condition failure, the next is started. If no sequence completes without condition failure, then suit-directive-try-each returns an error. If a particular application calls for all sequences to fail and still continue, then an empty sequence (nil) can be added to the Try Each Argument.

The argument to suit-directive-try-each is a list of SUIT_Command_Sequence. suit-directive-try-each does not specify a reporting policy.

#### suit-directive-override-parameters {#suit-directive-override-parameters}

suit-directive-override-parameters replaces any listed parameters that are already set with the values that are provided in its argument. This allows a manifest to prevent replacement of critical parameters.

Available parameters are defined in {{secparameters}}.

suit-directive-override-parameters does not specify a reporting policy.

#### suit-directive-fetch {#suit-directive-fetch}

suit-directive-fetch instructs the manifest processor to obtain one or more manifests or payloads, as specified by the manifest index and component index, respectively.

suit-directive-fetch can target one or more payloads. suit-directive-fetch retrieves each component listed in component-index. If component-index is True, instead of an integer, then all current manifest components are fetched. If component-index is an array, then all listed components are fetched.

suit-directive-fetch typically takes no arguments unless one is needed to modify fetch behavior. If an argument is needed, it must be wrapped in a bstr and set in suit-parameter-fetch-arguments.

suit-directive-fetch reads the URI parameter to find the source of the fetch it performs.

#### suit-directive-copy {#suit-directive-copy}

suit-directive-copy instructs the manifest processor to obtain one or more payloads, as specified by the component index. As described in {{index-true}} component index may be a single integer, a list of integers, or True. suit-directive-copy retrieves each component specified by the current component-index, respectively.

suit-directive-copy reads its source from suit-parameter-source-component ({{suit-parameter-source-component}}).

If either the source component parameter or the source component itself is absent, this command fails.

#### suit-directive-write {#suit-directive-write}

This directive writes a small block of data, specified in {{suit-parameter-content}}, to a component.

Encoding Considerations: Careful consideration must be taken to determine whether it is more appropriate to use an integrated payload or to use {{suit-parameter-content}} for a particular application. While the encoding of suit-directive-write is smaller than an integrated payload, a large suit-parameter-content payload may prevent the manifest processor from holding the command sequence in memory while executing it.

#### suit-directive-invoke {#suit-directive-invoke}

suit-directive-invoke directs the manifest processor to transfer execution to the current Component Index. When this is invoked, the manifest processor MAY be unloaded and execution continues in the Component Index. Arguments are provided to suit-directive-invoke through suit-parameter-invoke-arguments ({{suit-parameter-invoke-args}}) and are forwarded to the executable code located in Component Index in an application-specific way. For example, this could form the Linux Kernel Command Line if booting a Linux device.

If the executable code at Component Index is constructed in such a way that it does not unload the manifest processor, then the manifest processor may resume execution after the executable completes. This allows the manifest processor to invoke suitable helpers and to verify them with image conditions.

#### suit-directive-run-sequence {#suit-directive-run-sequence}

To enable conditional commands, and to allow several strictly ordered sequences to be executed out-of-order, suit-directive-run-sequence allows the manifest processor to execute its argument as a SUIT_Command_Sequence. The argument must be wrapped in a bstr. This also allows a sequence of instructions to be iterated over, once for each current component index, when component-index = true or component-index = list. See {{index-true}}.


When a sequence is executed, any failure of a condition causes immediate termination of the sequence.

When suit-directive-run-sequence completes, it forwards the last status code that occurred in the sequence. If the Soft Failure parameter is true, then suit-directive-run-sequence only fails when a directive in the argument sequence fails.

suit-parameter-soft-failure ({{suit-parameter-soft-failure}}) defaults to False when suit-directive-run-sequence begins. Its value is discarded when suit-directive-run-sequence terminates.

#### suit-directive-swap {#suit-directive-swap}

suit-directive-swap instructs the manifest processor to move the source to the destination and the destination to the source simultaneously. Swap has nearly identical semantics to suit-directive-copy except that suit-directive-swap replaces the source with the current contents of the destination in an application-defined way. As with suit-directive-copy, if the source component is missing, this command fails.

### Integrity Check Values {#integrity-checks}

When the Text section or any Command Sequence of the Update Procedure is made severable, it is moved to the Envelope and replaced with a SUIT_Digest. The SUIT_Digest is computed over the entire bstr enclosing the Manifest element that has been moved to the Envelope. Each element that is made severable from the Manifest is placed in the Envelope. The keys for the envelope elements have the same values as the keys for the manifest elements.

Each Integrity Check Value covers the corresponding Envelope Element as described in {{severable-fields}}.

## Severable Elements {#severable-fields}

Because the manifest can be used by different actors at different times, some parts of the manifest can be removed or "Severed" without affecting later stages of the lifecycle. Severing of information is achieved by separating that information from the signed container so that removing it does not affect the signature. This means that ensuring integrity of severable parts of the manifest is a requirement for the signed portion of the manifest. Severing some parts makes it possible to discard parts of the manifest that are no longer necessary. This is important because it allows the storage used by the manifest to be greatly reduced. For example, no text size limits are needed if text is removed from the manifest prior to delivery to a constrained device.

Elements are made severable by removing them from the manifest, encoding them in a bstr, and placing a SUIT_Digest of the bstr in the manifest so that they can still be authenticated. The SUIT_Digest typically consumes 4 bytes more than the size of the raw digest, therefore elements smaller than (Digest Bits)/8 + 4 SHOULD NOT be severable. Elements larger than (Digest Bits)/8 + 4 MAY be severable, while elements that are much larger than (Digest Bits)/8 + 4 SHOULD be severable.

Because of this, all command sequences in the manifest are encoded in a bstr so that there is a single code path needed for all command sequences.

# Access Control Lists {#access-control-lists}

To manage permissions in the manifest, there are three models that can be used.

First, the simplest model requires that all manifests are authenticated by a single trusted key. This mode has the advantage that only a root manifest needs to be authenticated, since all of its dependencies have digests included in the root manifest.

This simplest model can be extended by adding key delegation without much increase in complexity.

A second model requires an ACL to be presented to the Recipient, authenticated by a trusted party or stored on the Recipient. This ACL grants access rights for specific component IDs or Component Identifier prefixes to the listed identities or identity groups. Any identity can verify an image digest, but fetching into or fetching from a Component Identifier requires approval from the ACL.

A third model allows a Recipient to provide even more fine-grained controls: The ACL lists the Component Identifier or Component Identifier prefix that an identity can use, and also lists the commands and parameters that the identity can use in combination with that Component Identifier.

#  SUIT Digest Container {#SUIT_Digest}

The SUIT digest is a CBOR array containing two elements: an algorithm identifier and a bstr containing the bytes of the digest. Some forms of digest may require additional parameters. These can be added following the digest.

The values of the algorithm identifier are found in the IANA "COSE Algorithms" registry {{COSE_Alg}}, which was created by {{-hash-algs}}. SHA-256 (-16) MUST be implemented by all Manifest Processors.

Any other algorithm defined in the IANA "COSE Algorithms" registry, such as SHA-512 (-44), MAY be implemented in a Manifest Processor.

#  IANA Considerations {#iana}

IANA is requested to:

* allocate CBOR tag 107 (suggested) in the "CBOR Tags" registry for the SUIT Envelope.
* allocate CBOR tag 1070 (suggested) in the "CBOR Tags" registry for the SUIT Manifest.
* allocate media type application/suit-envelope in the "Media Types" registry, see below.
* setup several registries as described below.

IANA is requested to create a new category for Software Update for the Internet of Things (SUIT)
and a page within this category for SUIT manifests.

IANA is also requested to create several registries defined in the subsections below.

For each registry, values 0-255 are Standards Action and 256 or greater are Expert Review. Negative values -255 to 0 are Standards Action, and -256 and lower are Private Use.

New entries to those registries need to provide a label, a name and a reference to a specification that describes the functionality. More guidance on the expert review can be found below.

## SUIT Envelope Elements

IANA is requested to create a new registry for SUIT envelope elements.

Label | Name | Reference
---|---|---
2 | Authentication Wrapper | {{authentication-info}} of [TBD: this document]
3 | Manifest | {{manifest-structure}} of [TBD: this document]
16 | Payload Fetch | {{manifest-commands}} of [TBD: this document]
17 | Payload Installation | {{manifest-commands}} of [TBD: this document]
23 | Text Description | {{manifest-digest-text}} of [TBD: this document]


## SUIT Manifest Elements

IANA is requested to create a new registry for SUIT manifest elements.

Label | Name | Reference
---|---|---
1 | Encoding Version | {{manifest-version}} of [TBD: this document]
2 | Sequence Number | {{manifest-seqnr}} of [TBD: this document]
3 | Common Data | {{manifest-common}} of [TBD: this document]
4 | Reference URI | {{manifest-reference-uri}} of [TBD: this document]
7 | Image Validation | {{manifest-commands}} of [TBD: this document]
8 | Image Loading | {{manifest-commands}} of [TBD: this document]
9 | Image Invocation | {{manifest-commands}} of [TBD: this document]
16 | Payload Fetch | {{manifest-commands}} of [TBD: this document]
17 | Payload Installation | {{manifest-commands}} of [TBD: this document]
23 | Text Description | {{manifest-digest-text}} of [TBD: this document]

## SUIT Common Elements

IANA is requested to create a new registry for SUIT common elements.

Label | Name | Reference
---|---|---
2 | Component Identifiers | {{manifest-common}} of [TBD: this document]
4 | Common Command Sequence | {{manifest-common}} of [TBD: this document]

## SUIT Commands

IANA is requested to create a new registry for SUIT commands.

Label | Name | Reference
---|---|---
1 | Vendor Identifier | {{identifier-conditions}} of [TBD: this document]
2 | Class Identifier | {{identifier-conditions}} of [TBD: this document]
3 | Image Match | {{suit-condition-image-match}} of [TBD: this document]
4 | Reserved
5 | Component Slot | {{suit-condition-component-slot}} of [TBD: this document]
6 | Check Content | {{suit-condition-check-content}} of [TBD: this document]
12 | Set Component Index | {{suit-directive-set-component-index}} of [TBD: this document]
13 | Reserved
14 | Abort
15 | Try Each | {{suit-directive-try-each}} of [TBD: this document]
16 | Reserved
17 | Reserved
18 | Write Content | {{suit-directive-write}} of [TBD: this document]
19 | Reserved
20 | Override Parameters | {{suit-directive-override-parameters}} of [TBD: this document]
21 | Fetch | {{suit-directive-fetch}} of [TBD: this document]
22 | Copy | {{suit-directive-copy}} of [TBD: this document]
23 | Invoke | {{suit-directive-invoke}} of [TBD: this document]
24 | Device Identifier | {{identifier-conditions}} of [TBD: this document]
25 | Reserved
26 | Reserved
27 | Reserved
28 | Reserved
29 | Reserved
30 | Reserved
31 | Swap | {{suit-directive-swap}} of [TBD: this document]
32 | Run Sequence | {{suit-directive-run-sequence}} of [TBD: this document]
33 | Reserved
nint | Custom Condition | {{SUIT_Condition_Custom}} of [TBD: this document]

## SUIT Parameters

IANA is requested to create a new registry for SUIT parameters.

Label | Name | Reference
---|---|---
1 | Vendor ID | {{suit-parameter-vendor-identifier}} of [TBD: this document]
2 | Class ID | {{suit-parameter-class-identifier}} of [TBD: this document]
3 | Image Digest | {{suit-parameter-image-digest}} of [TBD: this document]
4 | Reserved
5 | Component Slot | {{suit-parameter-component-slot}} of [TBD: this document]
12 | Strict Order | {{suit-parameter-strict-order}} of [TBD: this document]
13 | Soft Failure | {{suit-parameter-soft-failure}} of [TBD: this document]
14 | Image Size | {{suit-parameter-image-size}} of [TBD: this document]
18 | Content | {{suit-parameter-content}} of [TBD: this document]
19 | Reserved
20 | Reserved
21 | URI | {{suit-parameter-uri}} of [TBD: this document]
22 | Source Component | {{suit-parameter-source-component}} of [TBD: this document]
23 | Invoke Args | {{suit-parameter-invoke-args}} of [TBD: this document]
24 | Device ID | {{suit-parameter-device-identifier}} of [TBD: this document]
26 | Reserved
27 | Reserved
28 | Reserved
29 | Reserved
30 | Reserved
nint | Custom | {{suit-parameter-custom}} of [TBD: this document]

## SUIT Text Values

IANA is requested to create a new registry for SUIT text values.

Label | Name | Reference
---|---|---
1 | Manifest Description | {{manifest-digest-text}} of [TBD: this document]
2 | Update Description | {{manifest-digest-text}} of [TBD: this document]
3 | Manifest JSON Source | {{manifest-digest-text}} of [TBD: this document]
4 | Manifest YAML Source | {{manifest-digest-text}} of [TBD: this document]
nint | Custom | {{manifest-digest-text}} of [TBD: this document]

## SUIT Component Text Values

IANA is requested to create a new registry for SUIT component text values.

Label | Name | Reference
---|---|---
1 | Vendor Name | {{manifest-digest-text}} of [TBD: this document]
2 | Model Name | {{manifest-digest-text}} of [TBD: this document]
3 | Vendor Domain | {{manifest-digest-text}} of [TBD: this document]
4 | Model Info | {{manifest-digest-text}} of [TBD: this document]
5 | Component Description | {{manifest-digest-text}} of [TBD: this document]
6 | Component Version | {{manifest-digest-text}} of [TBD: this document]
7 | Component Version Required | {{manifest-digest-text}} of [TBD: this document]
nint | Custom | {{manifest-digest-text}} of [TBD: this document]

## Expert Review Instructions

The IANA registries established in this document allow values to be added
based on expert review. This section gives some general guidelines for
what the experts should be looking for, but they are being designated
as experts for a reason, so they should be given substantial
latitude.

Expert reviewers should take into consideration the following points:

-  Point squatting should be discouraged.  Reviewers are encouraged
      to get sufficient information for registration requests to ensure
      that the usage is not going to duplicate one that is already
      registered, and that the point is likely to be used in
      deployments.  The zones tagged as private use
      are intended for testing purposes and closed environments;
      code points in other ranges should not be assigned for testing.

-  Specifications are required for the standards track range of point
      assignment.  Specifications should exist for  all other ranges,
      but early assignment before a specification is
      available is considered to be permissible.
      When specifications are not provided, the description provided
      needs to have sufficient information to identify what the point is
      being used for.

-  Experts should take into account the expected usage of fields when
      approving point assignment.  The fact that there is a range for
      standards track documents does not mean that a standards track
      document cannot have points assigned outside of that range.  The
      length of the encoded value should be weighed against how many
      code points of that length are left, the size of device it will be
      used on, and the number of code points left that encode to that
      size.

## Media Type Registration

This section registers the 'application/suit-envelope' media type in the
"Media Types" registry.  This media type are used to indicate that
the content is a SUIT envelope.

```
      Type name: application

      Subtype name: suit-envelope

      Required parameters: N/A

      Optional parameters: N/A

      Encoding considerations: binary

      Security considerations: See the Security Considerations section
      of [[This RFC]].

      Interoperability considerations: N/A

      Published specification: [[This RFC]]

      Applications that use this media type: Primarily used for
        Firmware and software updates although the content may
        also contain configuration data and other information
        related to software and firmware.

      Fragment identifier considerations: N/A

      Additional information:

      *  Deprecated alias names for this type: N/A

      *  Magic number(s): N/A

      *  File extension(s): cbor

      *  Macintosh file type code(s): N/A

      Person & email address to contact for further information:
      iesg@ietf.org

      Intended usage: COMMON

      Restrictions on usage: N/A

      Author: Brendan Moran, <brendan.moran.ietf@gmail.com>

      Change Controller: IESG

      Provisional registration?  No
```

#  Security Considerations

This document is about a manifest format protecting and describing how to retrieve, install, and invoke firmware images and as such it is part of a larger solution for delivering firmware updates to IoT devices. A detailed security treatment can be found in the architecture {{RFC9019}} and in the information model {{RFC9124}} documents.

# Acknowledgements

We would like to thank the following persons for their support in designing this mechanism:

*  
: {{{Milosch Meriac}}}
*  
: {{{Geraint Luff}}}
*  
: {{{Dan Ros}}}
*  
: {{{John-Paul Stanford}}}
*  
: {{{Hugo Vincent}}}
*  
: {{{Carsten Bormann}}}
*  
: {{{Øyvind Rønningstad}}}
*  
: {{{Frank Audun Kvamtrø}}}
*  
: {{{Krzysztof Chruściński}}}
*  
: {{{Andrzej Puzdrowski}}}
*  
: {{{Michael Richardson}}}
*  
: {{{David Brown}}}
*  
: {{{Emmanuel Baccelli}}}

We would like to thank our responsible area director, Roman Danyliw, for his detailed review.
Finally, we would like to thank our SUIT working group chairs (Dave Thaler, David Waltermire, Russ Housley)
for their feedback and support. 

--- back

# A. Full CDDL {#full-cddl}
In order to create a valid SUIT Manifest document the structure of the corresponding CBOR message MUST adhere to the following CDDL data definition.

To be valid, the following CDDL MUST have the COSE CDDL appended to it. The COSE CDDL can be obtained by following the directions in {{-cose, Section 1.4}}.

~~~ CDDL
{::include draft-ietf-suit-manifest.cddl}
~~~

# B. Examples {#examples}

The following examples demonstrate a small subset of the functionality of the manifest. Even a simple manifest processor can execute most of these manifests.

The examples are signed using the following ECDSA secp256r1 key:

~~~
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgApZYjZCUGLM50VBC
CjYStX+09jGmnyJPrpDLTz/hiXOhRANCAASEloEarguqq9JhVxie7NomvqqL8Rtv
P+bitWWchdvArTsfKktsCYExwKNtrNHXi9OB3N+wnAUtszmR23M4tKiW
-----END PRIVATE KEY-----
~~~

The corresponding public key can be used to verify these examples:

~~~
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEhJaBGq4LqqvSYVcYnuzaJr6qi/Eb
bz/m4rVlnIXbwK07HypLbAmBMcCjbazR14vTgdzfsJwFLbM5kdtzOLSolg==
-----END PUBLIC KEY-----
~~~

Each example uses SHA256 as the digest function.

Note that reporting policies are declared for each non-flow-control command in these examples. The reporting policies used in the examples are described in the following tables.

Policy | Label
---|---
suit-send-record-on-success | Rec-Pass
suit-send-record-on-failure | Rec-Fail
suit-send-sysinfo-success | Sys-Pass
suit-send-sysinfo-failure | Sys-Fail

Command | Sys-Fail | Sys-Pass | Rec-Fail | Rec-Pass
---|---|---|---|---
suit-condition-vendor-identifier | 1 | 1 | 1 | 1
suit-condition-class-identifier | 1 | 1 | 1 | 1
suit-condition-image-match | 1 | 1 | 1 | 1
suit-condition-component-slot | 0 | 1 | 0 | 1
suit-directive-fetch | 0 | 0 | 1 | 0
suit-directive-copy | 0 | 0 | 1 | 0
suit-directive-invoke | 0 | 0 | 1 | 0

## Example 0: Secure Boot

This example covers the following templates:

* Compatibility Check ({{template-compatibility-check}})
* Secure Boot ({{template-secure-boot}})

It also serves as the minimum example.

{::include examples/example0.txt}

## Example 1: Simultaneous Download and Installation of Payload

This example covers the following templates:

* Compatibility Check ({{template-compatibility-check}})
* Firmware Download ({{firmware-download-template}})

Simultaneous download and installation of payload. No secure boot is present in this example to demonstrate a download-only manifest.

{::include examples/example1.txt}

## Example 2: Simultaneous Download, Installation, Secure Boot, Severed Fields

This example covers the following templates:

* Compatibility Check ({{template-compatibility-check}})
* Secure Boot ({{template-secure-boot}})
* Firmware Download ({{firmware-download-template}})

This example also demonstrates severable elements ({{ovr-severable}}), and text ({{manifest-digest-text}}).

{::include examples/example2.txt}

## Example 3: A/B images

This example covers the following templates:

* Compatibility Check ({{template-compatibility-check}})
* Secure Boot ({{template-secure-boot}})
* Firmware Download ({{firmware-download-template}})
* A/B Image Template ({{a-b-template}})

{::include examples/example3.txt}


## Example 4: Load from External Storage

This example covers the following templates:

* Compatibility Check ({{template-compatibility-check}})
* Secure Boot ({{template-secure-boot}})
* Firmware Download ({{firmware-download-template}})
* Install ({{template-install}})
* Load ({{template-load-ext}})

{::include examples/example4.txt}

## Example 5: Two Images

This example covers the following templates:

* Compatibility Check ({{template-compatibility-check}})
* Secure Boot ({{template-secure-boot}})
* Firmware Download ({{firmware-download-template}})

Furthermore, it shows using these templates with two images.

{::include examples/example5.txt}

# C. Design Rational {#design-rationale}

In order to provide flexible behavior to constrained devices, while still allowing more powerful devices to use their full capabilities, the SUIT manifest encodes the required behavior of a Recipient device. Behavior is encoded as a specialized byte code, contained in a CBOR list. This promotes a flat encoding, which simplifies the parser. The information encoded by this byte code closely matches the operations that a device will perform, which promotes ease of processing. The core operations used by most update and trusted invocation operations are represented in the byte code. The byte code can be extended by registering new operations.

The specialized byte code approach gives benefits equivalent to those provided by a scripting language or conventional byte code, with two substantial differences. First, the language is extremely high level, consisting of only the operations that a device may perform during update and trusted invocation of a firmware image. Second, the language specifies linear behavior, without reverse branches. Conditional processing is supported, and parallel and out-of-order processing may be performed by sufficiently capable devices.

By structuring the data in this way, the manifest processor becomes a very simple engine that uses a pull parser to interpret the manifest. This pull parser invokes a series of command handlers that evaluate a Condition or execute a Directive. Most data is structured in a highly regular pattern, which simplifies the parser.

The results of this allow a Recipient to implement a very small parser for constrained applications. If needed, such a parser also allows the Recipient to perform complex updates with reduced overhead. Conditional execution of commands allows a simple device to perform important decisions at validation-time.

Dependency handling is vastly simplified as well. Dependencies function like subroutines of the language. When a manifest has a dependency, it can invoke that dependency's commands and modify their behavior by setting parameters. Because some parameters come with security implications, the dependencies also have a mechanism to reject modifications to parameters on a fine-grained level.

Developing a robust permissions system works in this model too. The Recipient can use a simple ACL that is a table of Identities and Component Identifier permissions to ensure that operations on components fail unless they are permitted by the ACL. This table can be further refined with individual parameters and commands.

Capability reporting is similarly simplified. A Recipient can report the Commands, Parameters, Algorithms, and Component Identifiers that it supports. This is sufficiently precise for a manifest author to create a manifest that the Recipient can accept.

The simplicity of design in the Recipient due to all of these benefits allows even a highly constrained platform to use advanced update capabilities.

## C.1 Design Rationale: Envelope {#design-rationale-envelope}

The Envelope is used instead of a COSE structure for several reasons:

1. This enables the use of Severable Elements ({{severable-fields}})
2. This enables modular processing of manifests, particularly with large signatures.
3. This enables multiple authentication schemes.
4. This allows integrity verification by a dependent to be unaffected by adding or removing authentication structures.

Modular processing is important because it allows a Manifest Processor to iterate forward over an Envelope, processing Delegation Chains and Authentication Blocks, retaining only intermediate values, without any need to seek forward and backwards in a stream until it gets to the Manifest itself. This allows the use of large, Post-Quantum signatures without requiring retention of the signature itself, or seeking forward and back.

Four authentication objects are supported by the Envelope:

* COSE_Sign_Tagged
* COSE_Sign1_Tagged
* COSE_Mac_Tagged
* COSE_Mac0_Tagged

The SUIT Envelope allows an Update Authority or intermediary to mix and match any number of different authentication blocks it wants without any concern for modifying the integrity of another authentication block. This also allows the addition or removal of an authentication blocks without changing the integrity check of the Manifest, which is important for dependency handling. See {{required-checks}}

## C.2 Byte String Wrappers

Byte string wrappers are used in several places in the suit manifest. The primary reason for wrappers it to limit the parser extent when invoked at different times, with a possible loss of context.

The elements of the suit envelope are wrapped both to set the extents used by the parser and to simplify integrity checks by clearly defining the length of each element.

The common block is re-parsed in order to find components identifiers from their indices, to find dependency prefixes and digests from their identifiers, and to find the shared sequence. The shared sequence is wrapped so that it matches other sequences, simplifying the code path.

A severed SUIT command sequence will appear in the envelope, so it must be wrapped as with all envelope elements. For consistency, command sequences are also wrapped in the manifest. This also allows the parser to discern the difference between a command sequence and a SUIT_Digest.

Parameters that are structured types (arrays and maps) are also wrapped in a bstr. This is so that parser extents can be set correctly using only a reference to the beginning of the parameter. This enables a parser to store a simple list of references to parameters that can be retrieved when needed.


# D. Implementation Conformance Matrix {#implementation-matrix}

This section summarizes the functionality a minimal manifest processor
implementation needs
to offer to claim conformance to this specification, in the absence of
an application profile standard specifying otherwise.

The subsequent table shows the conditions.

Name | Reference | Implementation
---|---|---
Vendor Identifier | {{uuid-identifiers}} | REQUIRED
Class Identifier | {{uuid-identifiers}} | REQUIRED
Device Identifier | {{uuid-identifiers}} | OPTIONAL
Image Match | {{suit-condition-image-match}} | REQUIRED
Check Content | {{suit-condition-check-content}} | OPTIONAL
Component Slot | {{suit-condition-component-slot}} | OPTIONAL
Abort | {{suit-condition-abort}} | OPTIONAL
Custom Condition | {{SUIT_Condition_Custom}} | OPTIONAL

The subsequent table shows the directives.

Name | Reference | Implementation
---|---|---
Set Component Index | {{suit-directive-set-component-index}} | REQUIRED if more than one component
Write Content | {{suit-directive-write}} | OPTIONAL
Try Each | {{suit-directive-try-each}} | OPTIONAL
Override Parameters | {{suit-directive-override-parameters}} | REQUIRED
Fetch | {{suit-directive-fetch}} | REQUIRED for Updater
Copy | {{suit-directive-copy}} | OPTIONAL
Invoke | {{suit-directive-invoke}} | REQUIRED for Bootloader
Run Sequence | {{suit-directive-run-sequence}} | OPTIONAL
Swap | {{suit-directive-swap}} | OPTIONAL

The subsequent table shows the parameters.

Name | Reference | Implementation
---|---|---
Vendor ID | {{suit-parameter-vendor-identifier}} | REQUIRED
Class ID | {{suit-parameter-class-identifier}} | REQUIRED
Image Digest | {{suit-parameter-image-digest}} | REQUIRED
Image Size | {{suit-parameter-image-size}} | REQUIRED
Component Slot | {{suit-parameter-component-slot}} | OPTIONAL
Content | {{suit-parameter-content}} | OPTIONAL
URI | {{suit-parameter-uri}} | REQUIRED for Updater
Source Component | {{suit-parameter-source-component}} | OPTIONAL
Invoke Args | {{suit-parameter-invoke-args}} | OPTIONAL
Device ID | {{suit-parameter-device-identifier}} | OPTIONAL
Strict Order | {{suit-parameter-strict-order}} | OPTIONAL
Soft Failure | {{suit-parameter-soft-failure}} | OPTIONAL
Custom | {{suit-parameter-custom}} | OPTIONAL
