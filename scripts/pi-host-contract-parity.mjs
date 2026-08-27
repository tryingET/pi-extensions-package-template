#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";

const canonical = JSON.parse(
	fs.readFileSync("contract/pi-host-contract.json", "utf8"),
);
const roots = ["copier-template", "copier-template-monorepo-package"];
const metadataContract = { ...canonical };
delete metadataContract.typescript;

assert.equal(
	canonical.hostBaseline,
	canonical.devTestFloor,
	"host baseline and tested floor drifted",
);
for (const range of Object.values(canonical.peerCompatibility)) {
	assert.equal(
		range,
		"*",
		"Pi peers must remain host-provided compatibility declarations",
	);
}

for (const root of roots) {
	const packageTemplate = JSON.parse(
		fs.readFileSync(`${root}/package.json.jinja`, "utf8"),
	);
	assert.deepEqual(
		packageTemplate["x-pi-template"]?.piHostContract,
		metadataContract,
		`${root} metadata drifted from the canonical Pi host contract`,
	);
	for (const [name, range] of Object.entries(canonical.peerCompatibility)) {
		assert.equal(
			packageTemplate.devDependencies?.[name],
			canonical.devTestFloor,
		);
		assert.equal(packageTemplate.peerDependencies?.[name], range);
	}
	assert.equal(
		packageTemplate.devDependencies?.typescript,
		canonical.typescript,
	);

	const validator = fs.readFileSync(
		`${root}/scripts/validate-structure.mjs`,
		"utf8",
	);
	for (const line of [
		`const PI_HOST_BASELINE = "${canonical.hostBaseline}";`,
		`const PI_DEV_TEST_FLOOR = "${canonical.devTestFloor}";`,
		`const PI_TEMPLATE_SOURCE = "${canonical.source}";`,
	]) {
		assert.ok(validator.includes(line), `${root} validator drifted: ${line}`);
	}
	for (const packageName of Object.keys(canonical.peerCompatibility)) {
		assert.ok(validator.includes(`"${packageName}"`), `${root} validator omitted ${packageName}`);
	}
	assert.ok(
		validator.includes(
			`p.devDependencies?.typescript !== "${canonical.typescript}"`,
		),
		`${root} validator TypeScript pin drifted`,
	);

	const generatedTest = fs.readFileSync(
		`${root}/tests/pi-host-contract.test.mjs`,
		"utf8",
	);
	for (const line of [
		`const HOST_BASELINE = "${canonical.hostBaseline}";`,
		`const DEV_TEST_FLOOR = "${canonical.devTestFloor}";`,
		`const TEMPLATE_SOURCE = "${canonical.source}";`,
	]) {
		assert.ok(
			generatedTest.includes(line),
			`${root} generated test drifted: ${line}`,
		);
	}
	for (const packageName of Object.keys(canonical.peerCompatibility)) {
		assert.ok(generatedTest.includes(`"${packageName}"`), `${root} test omitted ${packageName}`);
	}

	const readme = fs.readFileSync(`${root}/README.md.jinja`, "utf8");
	assert.ok(readme.includes(`host baseline: Pi \`${canonical.hostBaseline}\``));
	assert.ok(readme.includes("host-provided compatibility declarations"));
	assert.ok(
		readme.includes(
			`\`${canonical.devTestFloor}\` is the tested development baseline`,
		),
	);
}

assert.equal(
	fs.readFileSync("copier-template/tests/pi-host-contract.test.mjs", "utf8"),
	fs.readFileSync(
		"copier-template-monorepo-package/tests/pi-host-contract.test.mjs",
		"utf8",
	),
	"generated Pi host tests must stay identical across topologies",
);
assert.equal(
	fs.readFileSync("copier-template/tsconfig.json", "utf8"),
	fs.readFileSync("copier-template-monorepo-package/tsconfig.json", "utf8"),
	"generated TypeScript configs must stay identical across topologies",
);

for (const contractPath of [
	"contract/generated-repo.contract.json",
	"contract/generated-monorepo-package.contract.json",
]) {
	const contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));
	for (const required of ["tsconfig.json", "tests/pi-host-contract.test.mjs"]) {
		assert.ok(
			contract.required_files.includes(required),
			`${contractPath} must require ${required}`,
		);
	}
}

console.log("Pi host contract canonical/parity guard passed.");
